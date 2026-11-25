"""Grimble (dredge) native body r7: the goo arm as one mesh on the arm chain, the pack rigid, the coin cap gilded.

Meshy fused the goo arm's tail and puddle to the right shin and weights the tail to both arm and legs, so a clip
dragged a ribbon from the hand to the floor; r6 cut the goo and left floating pieces. This re-skins the r5 body glb
(two primitives skin-native / skin-goo share the vertex buffer; brass/leather pack and the coin cap are their own):

- goo: no cuts. Its own copy of its vertices; Meshy's weights (the r3 file) with every leg bone removed, one weight
  per welded position (a UV seam whose halves skin differently tears); vertices left empty take their neighbours'
  mean. Blended by height from the arm chain (above TAIL_Y1) to the hips (below TAIL_Y0), the tail end keeping
  `tail_arm` of the arm's motion.
- skin: no arm weight below SKIN_LOW_Y (the fused shin). Skin near its own holes gets an inside-out lining, so the
  far wall shows instead of the ink hull once the goo no longer covers a hole.
- pack: rigid on the spine, a blend of the two spine bones around each vertex's height.
- coin cap: texture hue COIN_HUE (orange to gold), scaled COIN_SCALE about COIN_PIVOT.

  python3 tools/meshy/dredge_reskin.py OUT.glb R5.glb R3.glb [tail_arm]    # build
  python3 tools/meshy/dredge_reskin.py --stretch FILE.glb                   # long stretched edges per clip

Needs numpy, scipy and PIL. Reports edges stretched >3x and longer than 6 cm for Idle, Attack, run, walk, jump.
"""

import io
import sys

import native_pack as n
import numpy as np
import scipy.sparse as sp
from PIL import Image
from scipy.spatial import cKDTree

SKIN_LOW_Y = 0.75  # m: the skin below this (the shin the goo is fused to) takes no arm weight
TAIL_Y0, TAIL_Y1 = 0.3, 0.9  # m: the goo blends from the hips (below Y0) to the arm chain (above Y1)
COIN_PIVOT = np.array([0.0, 1.78, 0.14])  # m: the cap's base centre on the skull
COIN_SCALE = np.array([0.72, 0.7, 0.72])  # the cap's size against Meshy's lump
COIN_HUE = 14  # degrees: the cap's orange (hue 24) to coin gold (hue 38)
LINING_R = 0.25  # m: skin this close to a hole in the skin gets an inner lining (the far wall seen through the hole)
LINING_DEPTH = 0.004  # m: the lining sits this far inside the skin
LONG_EDGE = 0.06  # m: an edge this long after skinning, and over 3x its rest length, shows as a sheet
HOLE_Y = 1.0  # m: only holes below this (the legs and hips) are covered
TAIL_ARM = 0.15  # share of the arm's motion the goo's lowest end keeps; the rest rides the hips
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
            ln = np.linalg.norm(q[e[:, 0]] - q[e[:, 1]], axis=1)
            cells.append(f"{clip}{t}: {int(((ln / rest > 3) & (ln > LONG_EDGE)).sum())} long, longest {ln.max():.2f} m")
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


def weld_ids(pos):
    """One id per distinct position: Meshy splits vertices at UV seams, and a seam whose halves skin differently tears."""
    return np.unique(np.round(pos, 5), axis=0, return_inverse=True)[1].ravel()


def fill_unknown(d, unknown, faces, wid, welded=False):
    """Harmonic fill: each unknown row takes the mean of its neighbours' rows (welded positions count as one vertex)."""
    nw = wid.max() + 1
    if not welded:
        pool = sp.coo_matrix((np.ones(len(d)), (wid, np.arange(len(d)))), (nw, len(d))).tocsr()
        d, unknown = (pool @ d) / np.maximum(np.asarray(pool.sum(1)), 1), (pool @ unknown.astype(float)) > 0
    fw = wid[faces]
    e = np.concatenate([fw[:, [0, 1]], fw[:, [1, 2]], fw[:, [2, 0]]])
    adj = sp.coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), (nw, nw)).tocsr()
    adj = ((adj + adj.T) > 0).astype(np.float32)
    deg = np.maximum(np.asarray(adj.sum(1)).ravel(), 1)
    for _ in range(FILL_ITERS):
        d = np.where(unknown[:, None], (adj @ d) / deg[:, None], d)
    return d if welded else d[wid]


def goo_weights(rig5, rig3, tail_arm):
    """Weights (vertices x joints): goo on the arm chain with no cuts, skin as r5 but with no arm weight on the legs."""
    pos, j5, w5 = rig5.verts(0)
    _, j3, w3 = rig3.verts(0)
    names, nb = rig5.names, len(rig5.names)
    ix = lambda group: [names.index(x) for x in group]  # noqa: E731
    fg, fn = rig5.faces(1), rig5.faces(0)
    goo = np.zeros(len(pos), bool)
    goo[np.unique(fg)] = True
    d5, dg = dense(j5, w5, nb), dense(j3, w3, nb)
    low = pos[:, 1] < SKIN_LOW_Y  # the shin Meshy fused the goo to (shared vertices too) carries no arm weight
    d5[np.ix_(low, ix(RIGHT_ARM))] = 0
    dg[:, ix(ALL_LEGS)] = 0  # the goo hangs from the arm: never a leg bone
    wid = weld_ids(pos)
    nw = wid.max() + 1
    pool = sp.coo_matrix((np.ones(len(pos)), (wid, np.arange(len(pos)))), (nw, len(pos))).tocsr()
    gw = np.zeros(nw, bool)
    gw[wid[goo]] = True
    skin_unknown = low & (d5.sum(1) < 0.05)  # skin that only the arm held: weights from its neighbours
    d5[skin_unknown] = 0
    d5 = fill_unknown(d5, skin_unknown, fn, wid)
    arm = pool @ dg
    known = arm.sum(1) > 0.05
    arm = arm / np.maximum(arm.sum(1, keepdims=True), 1e-9)
    arm[~known] = 0
    arm = fill_unknown(arm, gw & ~known, wid[fg], np.arange(nw), True)  # unweighted goo (tail, puddle) takes its neighbours'
    y = np.zeros(nw)
    y[wid] = pos[:, 1]
    t = np.clip((y - TAIL_Y0) / (TAIL_Y1 - TAIL_Y0), 0, 1)
    t = t * t * (3 - 2 * t)  # 1 = the arm, 0 = the tail end
    keep = (tail_arm + (1 - tail_arm) * t)[:, None]  # the share of the arm's motion; the rest rides the hips
    hips = np.zeros(nb)
    hips[names.index("Hips")] = 1
    goo_w = keep * arm + (1 - keep) * hips
    fs = wid[fn]
    e = np.sort(np.concatenate([fs[:, [0, 1]], fs[:, [1, 2]], fs[:, [2, 0]]]), 1)
    u, c = np.unique(e, axis=0, return_counts=True)
    rim = np.unique(u[c == 1])
    wpos = np.zeros((nw, 3))
    wpos[wid] = pos
    rim = rim[wpos[rim, 1] < HOLE_Y]  # the skin's open edges on the legs: the holes the goo covers
    dist = cKDTree(wpos[rim]).query(wpos)[0]
    near_hole = (dist <= LINING_R) & (wpos[:, 1] < HOLE_Y)
    return d5, goo_w[wid], goo, fg, len(pos), near_hole[wid][fn].all(1)


def pack_weights(pos, names):
    k = np.clip(np.searchsorted(SPINE_Y, np.clip(pos[:, 1], SPINE_Y[0], SPINE_Y[-1])) - 1, 0, 2)
    f = (np.clip(pos[:, 1], SPINE_Y[0], SPINE_Y[-1]) - SPINE_Y[k]) / (SPINE_Y[k + 1] - SPINE_Y[k])
    ids = np.array([names.index(x) for x in SPINE])
    joints = np.zeros((len(pos), 4), np.uint16)
    weights = np.zeros((len(pos), 4), np.float32)
    joints[:, 0], joints[:, 1], weights[:, 0], weights[:, 1] = ids[k], ids[k + 1], 1 - f, f
    return joints, weights


def gild_coins(js, b, out):
    """The coin cap's texture hue-shifted from Meshy's orange to the turnaround's gold."""
    mat = next(m for m in js["materials"] if m["name"] == "brass-coin")
    img = js["images"][js["textures"][mat["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]]
    bv = js["bufferViews"][img["bufferView"]]
    raw = b[bv.get("byteOffset", 0) : bv.get("byteOffset", 0) + bv["byteLength"]]
    hsv = np.asarray(Image.open(io.BytesIO(raw)).convert("HSV")).astype(float)
    hsv[..., 0] = (hsv[..., 0] + COIN_HUE / 360 * 255) % 255
    buf = io.BytesIO()
    Image.fromarray(hsv.astype(np.uint8), "HSV").convert("RGB").save(buf, "JPEG", quality=92)
    img["bufferView"] = out.add_view(buf.getvalue())


def shrink_coins(js, b, out):
    """The coin cap smaller (the turnaround's is a thin crown of coins; Meshy's is a head-sized lump), about COIN_PIVOT."""
    prim = next(p for p in js["meshes"][0]["primitives"] if js["materials"][p["material"]]["name"] == "brass-coin")
    pos = n.floats(js, b, prim["attributes"]["POSITION"])
    pos = COIN_PIVOT + (pos - COIN_PIVOT) * COIN_SCALE
    acc = out.add_floats(pos.astype(np.float32), "VEC3")
    js["accessors"][acc].update(min=pos.min(0).tolist(), max=pos.max(0).tolist())
    prim["attributes"]["POSITION"] = acc


def build(out_path, r5_path, r3_path, tail_arm):
    rig5, rig3 = Rig(r5_path), Rig(r3_path)
    js, b = rig5.js, rig5.b
    d_skin, d_goo, goo, f_goo, nv, lined = goo_weights(rig5, rig3, tail_arm)
    f_skin = rig5.faces(0)
    gv = np.flatnonzero(goo)  # the goo gets its own copy of its vertices, so the skin's weights never touch it
    lv = np.unique(f_skin[lined])  # the lining: inside-out copies of the skin around its holes, riding the same bones
    joints, weights = top4(np.concatenate([d_skin, d_goo[gv], d_skin[lv]]))
    at0 = js["meshes"][0]["primitives"][0]["attributes"]
    attrs = {k: n.floats(js, b, v)[:nv] for k, v in at0.items() if k not in ("JOINTS_0", "WEIGHTS_0")}
    new_id = np.full(nv, -1, np.int64)
    new_id[gv] = nv + np.arange(len(gv))
    lining_id = np.full(nv, -1, np.int64)
    lining_id[lv] = nv + len(gv) + np.arange(len(lv))
    for k in attrs:
        lining = attrs[k][lv]
        if k == "POSITION":
            lining = lining - LINING_DEPTH * attrs["NORMAL"][lv]
        elif k == "NORMAL":
            lining = -lining
        attrs[k] = np.concatenate([attrs[k], attrs[k][gv], lining])
    attrs["JOINTS_0"], attrs["WEIGHTS_0"] = joints, weights
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
    f_out = new_id[f_goo].astype(np.uint32)
    js["accessors"].append({"bufferView": out.add_view(f_out.tobytes()), "componentType": 5125, "count": int(f_out.size), "type": "SCALAR"})
    prims[1]["indices"] = len(js["accessors"]) - 1
    f_skin = np.concatenate([f_skin, lining_id[f_skin[lined]][:, ::-1]]).astype(np.uint32)
    js["accessors"].append({"bufferView": out.add_view(f_skin.tobytes()), "componentType": 5125, "count": int(f_skin.size), "type": "SCALAR"})
    prims[0]["indices"] = len(js["accessors"]) - 1
    for p in prims:
        if js["materials"][p["material"]]["name"] in ("brass-pack", "leather-pack"):
            pj, pw = pack_weights(n.floats(js, b, p["attributes"]["POSITION"]), rig5.names)
            p["attributes"]["WEIGHTS_0"] = out.add_floats(pw, "VEC4")
            js["accessors"].append({"bufferView": out.add_view(pj.tobytes()), "componentType": 5123, "count": len(pj), "type": "VEC4"})
            p["attributes"]["JOINTS_0"] = len(js["accessors"]) - 1
    gild_coins(js, b, out)
    shrink_coins(js, b, out)
    compact(out)
    out.write(out_path)
    print("goo vertices", len(gv), "triangles", len(f_goo), "lining triangles", int(lined.sum()), "written", out_path)


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
        build(sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4]) if len(sys.argv) > 4 else TAIL_ARM)
