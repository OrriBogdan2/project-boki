"""Grimble (dredge) native r8: loose islands deleted, the goo's tail hung on a bone chain.

Runs on the r7 body (tools/meshy/dredge_reskin.py output) and writes the game glb:

- islands: every group of triangles that touches no other (vertices within ISLAND_TOL) and has fewer than MIN_TRIS
  triangles is deleted, per body primitive (skin, goo, leather pack; the brass fittings and the coin pile are made of
  many small pieces on purpose). `--islands FILE` counts them (the proof of "0 loose islands").
- tail chain: four bones (GooTail0..3) under RightHand at the goo's own centre line, the goo below the hand weighted
  along them by height (hat weights, so it bends between two bones and never shears against the hips). Baked into
  every clip: each segment keeps its rest direction (it hangs) and follows the bone above it by only TAIL_FOLLOW,
  with a lag that grows down the chain, so a swung arm drags the tail round instead of stretching it.

  python3 tools/meshy/dredge_post.py OUT.glb IN.glb
  python3 tools/meshy/dredge_post.py --islands FILE.glb

Needs numpy and scipy (the venv).
"""

import io
import sys

import dredge_reskin as rs
import native_pack as n
import numpy as np
import scipy.sparse as sp
from scipy.sparse.csgraph import connected_components
from PIL import Image
from scipy.spatial import cKDTree

ISLAND_TOL = 0.001  # m: vertices this close are one vertex (UV seams, decimation splits)
MIN_TRIS = 1000  # an island of fewer triangles is a loose chunk (the body, goo, pack and cap are all far larger)
CLEANED = ("skin-native", "skin-goo", "leather-pack")  # the primitives that must be one piece each
BLADE_X, BLADE_Y = (-0.17, 0.02), (0.10, 0.62)  # m: the pale crescent Meshy fused to the right heel (skin, rest pose)
BLADE_GROW = 0.06  # m: pale triangles this close to the crescent's body go with it (its root at the foot)
HAND = "RightHand"
CHAIN_Y = (0.97, 0.70, 0.43, 0.16)  # m: rest height of GooTail0..3 (the first is the hand's own origin)
FADE_Y = 1.15  # m: the goo above this keeps its arm weights; between this and the hand it blends into GooTail0
# share of the bone above's turn each segment takes (the first is the hand's own); the rest it keeps hanging
TAIL_FOLLOW = (1.0, 0.6, 0.5, 0.5)
LAG = (0.0, 0.4, 0.5, 0.6)  # per frame carry-over of each segment's direction (a later swing down the chain)
FPS = 30.0
# the attack clip keeps this share of its head and upper-spine bend
LUNGE_CLIP, LUNGE_BONES, LUNGE_KEEP = "Attack", ("Spine02", "Spine01", "neck", "Head"), 0.35


def island_labels(pos, faces, tol=ISLAND_TOL):
    """Island index per triangle: triangles are one island when they share a vertex or vertices within tol."""
    used = np.unique(faces)
    slot = np.zeros(len(pos), np.int64)
    slot[used] = np.arange(len(used))
    pairs = cKDTree(pos[used]).query_pairs(tol, output_type="ndarray")
    f = slot[faces]
    e = np.concatenate([f[:, [0, 1]], f[:, [1, 2]], pairs])
    g = sp.coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), (len(used), len(used)))
    return connected_components(g, directed=False)[1][f[:, 0]]


def prim_faces(js, b, prim):
    ia = js["accessors"][prim["indices"]]
    dt = np.uint32 if ia["componentType"] == 5125 else np.uint16
    raw = np.frombuffer(n.view_bytes(js, b, ia["bufferView"]), dt, ia["count"], ia.get("byteOffset", 0))
    return raw.reshape(-1, 3).astype(np.int64)


def pale_tris(js, b, prim, pos, faces):
    """Triangles whose texture is the goo's pale pink (the crescent's colour; the skin proper is darker)."""
    tex = js["materials"][prim["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    bv = js["bufferViews"][js["images"][js["textures"][tex]["source"]]["bufferView"]]
    px = np.asarray(Image.open(io.BytesIO(b[bv.get("byteOffset", 0) :][: bv["byteLength"]])).convert("RGB"))
    uv = n.floats(js, b, prim["attributes"]["TEXCOORD_0"])[faces].mean(1)
    h, w = px.shape[:2]
    c = px[(np.clip(uv[:, 1], 0, 0.999) * h).astype(int), (np.clip(uv[:, 0] % 1, 0, 0.999) * w).astype(int)].astype(int)
    return (c[:, 0] > 170) & (c[:, 1] > 110) & (c[:, 2] > 150)


def drop_blade(js, b, out):
    """Deletes the pale crescent on the right heel (a sheet of skin rising beside the shin); returns its triangles."""
    prim = js["meshes"][0]["primitives"][0]
    pos = n.floats(js, b, prim["attributes"]["POSITION"])
    f = prim_faces(js, b, prim)
    pale = pale_tris(js, b, prim, pos, f)
    c = pos[f].mean(1)
    core = pale & (c[:, 0] > BLADE_X[0]) & (c[:, 0] < BLADE_X[1]) & (c[:, 1] > BLADE_Y[0]) & (c[:, 1] < BLADE_Y[1])
    idx = np.flatnonzero(core)
    lab = island_labels(pos, f[idx], 0.006)
    body = np.zeros(len(f), bool)
    body[idx[lab == np.bincount(lab).argmax()]] = True  # the crescent is the biggest pale piece in the box
    near = cKDTree(pos[np.unique(f[body])]).query(c)[0] < BLADE_GROW
    gone = body | (near & pale & (c[:, 1] > 0.02))
    js["accessors"].append(
        {"bufferView": out.add_view(f[~gone].astype(np.uint32).tobytes()), "componentType": 5125,
         "count": int((~gone).sum()) * 3, "type": "SCALAR"}
    )
    prim["indices"] = len(js["accessors"]) - 1
    return int(gone.sum())


def slerp_to(q, rest, keep):
    """Keys q (frames x xyzw) turned back toward the rest rotation: keep = 1 leaves them, 0 is the rest pose."""
    q = q * np.where((q @ rest) < 0, -1.0, 1.0)[:, None]
    d = np.clip(q @ rest, -1, 1)
    th = np.arccos(d)
    a = np.where(th < 1e-5, 1.0, np.sin(keep * th) / np.maximum(np.sin(th), 1e-9))
    c = np.where(th < 1e-5, 1.0, np.sin((1 - keep) * th) / np.maximum(np.sin(th), 1e-9))
    out = a[:, None] * q + c[:, None] * rest
    return out / np.linalg.norm(out, axis=1, keepdims=True)


def soften_lunge(js, b, out):
    """Meshy's lunge folds the spine forward: the attack clip's bend turned back toward upright by 1 - LUNGE_KEEP."""
    clip = next(a for a in js["animations"] if a["name"] == LUNGE_CLIP)
    for ch in clip["channels"]:
        node = js["nodes"][ch["target"]["node"]]
        if node.get("name") in LUNGE_BONES and ch["target"]["path"] == "rotation":
            smp = clip["samplers"][ch["sampler"]]
            keys = n.floats(js, b, smp["output"]).astype(float)
            rest = np.array(node.get("rotation", [0, 0, 0, 1]))
            smp["output"] = out.add_floats(slerp_to(keys, rest, LUNGE_KEEP), "VEC4")


def count_islands(path):
    js, b = n.load(path)
    for i, prim in enumerate(js["meshes"][0]["primitives"]):
        pos = n.floats(js, b, prim["attributes"]["POSITION"])
        f = prim_faces(js, b, prim)
        size = np.bincount(island_labels(pos, f))
        print(f"{js['materials'][prim['material']]['name']:14s} {len(f):6d} tris, {len(size)} islands, "
              f"{int((size < MIN_TRIS).sum())} under {MIN_TRIS} tris (largest {size.max()})")


def drop_islands(js, b, out):
    """Deletes the small islands of every primitive; returns the number of islands and triangles removed."""
    gone = [0, 0]
    for prim in js["meshes"][0]["primitives"]:
        if js["materials"][prim["material"]]["name"] not in CLEANED:
            continue
        pos = n.floats(js, b, prim["attributes"]["POSITION"])
        f = prim_faces(js, b, prim)
        lab = island_labels(pos, f)
        size = np.bincount(lab)
        keep = size[lab] >= MIN_TRIS
        gone[0] += int((size < MIN_TRIS).sum())
        gone[1] += int((~keep).sum())
        js["accessors"].append(
            {"bufferView": out.add_view(f[keep].astype(np.uint32).tobytes()), "componentType": 5125,
             "count": int(keep.sum()) * 3, "type": "SCALAR"}
        )
        prim["indices"] = len(js["accessors"]) - 1
    return gone


def arc(a, b):
    """The rotation matrix turning unit vector a onto unit vector b (the short way)."""
    v, c = np.cross(a, b), float(a @ b)
    if c < -0.9999:
        axis = np.cross(a, [1.0, 0, 0] if abs(a[0]) < 0.9 else [0, 1.0, 0])
        axis /= np.linalg.norm(axis)
        return 2 * np.outer(axis, axis) - np.eye(3)
    k = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + k + k @ k / (1 + c)


def mat_quat(m):
    """Quaternion (x, y, z, w) of a rotation matrix."""
    t = np.trace(m)
    if t > 0:
        s = 2 * np.sqrt(t + 1)
        q = [(m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s, s / 4]
    else:
        i = int(np.argmax(np.diag(m)))
        j, k = (i + 1) % 3, (i + 2) % 3
        s = 2 * np.sqrt(1 + m[i, i] - m[j, j] - m[k, k])
        q = [0.0] * 4
        q[i], q[3] = s / 4, (m[k, j] - m[j, k]) / s
        q[j], q[k] = (m[j, i] + m[i, j]) / s, (m[k, i] + m[i, k]) / s
    q = np.array(q)
    return q / np.linalg.norm(q)


def goo_vertices(js, b):
    """Indices of the goo primitive's vertices (own copy: no other primitive uses them)."""
    prims = js["meshes"][0]["primitives"]
    goo = np.unique(prim_faces(js, b, prims[1]))
    other = np.unique(prim_faces(js, b, prims[0]))
    assert not np.intersect1d(goo, other).size, "goo shares vertices with the skin"
    return goo


def chain_points(pos, hand):
    """Rest origins of GooTail0..3 and the tip: the hand's, then the goo's centre (x, z) in a slab at each height."""
    pts = [hand]
    for y in CHAIN_Y[1:]:
        near = pos[np.abs(pos[:, 1] - y) < 0.06]
        pts.append(np.array([near[:, 0].mean(), y, near[:, 2].mean()]))
    tip = pos[pos[:, 1] < 0.1]
    pts.append(np.array([tip[:, 0].mean(), 0.0, tip[:, 2].mean()]))
    return np.array(pts)


def hat_weights(y, ys):
    """Weights of GooTail0..3 at heights y: 1 above the first and below the last, linear between two bones."""
    w = np.zeros((len(y), len(ys)))
    yc = np.clip(y, ys[-1], ys[0])
    k = np.clip(np.searchsorted(-ys, -yc) - 1, 0, len(ys) - 2)
    f = (ys[k] - yc) / (ys[k] - ys[k + 1])
    w[np.arange(len(y)), k], w[np.arange(len(y)), k + 1] = 1 - f, f
    return w


def new_goo_weights(joints, weights, pos, first, ys):
    """Goo weights (vertices x 4 joints): the arm's above FADE_Y, the tail chain's below the hand."""
    nb = first + len(CHAIN_Y)
    d = rs.dense(joints, weights, nb)
    c = np.clip((FADE_Y - pos[:, 1]) / (FADE_Y - ys[0]), 0, 1)
    c = (c * c * (3 - 2 * c))[:, None]
    d = (1 - c) * d
    d[:, first:] = c * hat_weights(pos[:, 1], ys)
    return rs.top4(d)


def rest_world(rig, name):
    m = np.linalg.inv(rig.ibm[rig.names.index(name)])
    return m[:3, :3], m[:3, 3]


def clip_times(rig, clip):
    top = max(n.floats(rig.js, rig.b, s["input"])[:, 0].max() for s in rig.clips[clip]["samplers"])
    return np.unique(np.r_[np.arange(0, top, 1 / FPS), top])


def tail_keys(rig, clip, rest_pts):
    """Local rotation keys (frames x bones x xyzw) of the chain in one clip (two passes round, so a loop is settled)."""
    ih = rig.names.index(HAND)
    r0, _ = rest_world(rig, HAND)
    seg = rest_pts[1:] - rest_pts[:-1]
    length = np.linalg.norm(seg, axis=1)
    rest_dir = seg / length[:, None]
    times = clip_times(rig, clip)
    held = rest_dir.copy()
    keys = np.zeros((len(times), len(seg), 4))
    for rep in range(2):
        for ti, t in enumerate(times):
            world = rig.pose(clip, t)[ih] @ np.linalg.inv(rig.ibm[ih])
            rh = world[:3, :3]
            rh = rh / np.linalg.norm(rh, axis=0)
            carry = rh @ r0.T  # the hand's turn since rest
            prev = carry
            for k in range(len(seg)):
                follow = prev @ rest_dir[k]
                u = TAIL_FOLLOW[k] * follow + (1 - TAIL_FOLLOW[k]) * rest_dir[k]
                u /= np.linalg.norm(u)
                held[k] = LAG[k] * held[k] + (1 - LAG[k]) * u
                held[k] /= np.linalg.norm(held[k])
                q = arc(rest_dir[k], held[k])
                keys[ti, k] = mat_quat(r0.T @ prev.T @ q @ r0)
                prev = q
    return times, keys


def add_chain(js, b, out, rig, rest_pts):
    """The chain's nodes, skin joints and inverse bind matrices; returns the first new joint index."""
    r0, _ = rest_world(rig, HAND)
    hand_node = rig.joints[rig.names.index(HAND)]
    first = len(rig.joints)
    parent, ibm = hand_node, []
    for k in range(len(CHAIN_Y)):
        node = {"name": f"GooTail{k}", "rotation": [0.0, 0.0, 0.0, 1.0]}
        node["translation"] = (r0.T @ (rest_pts[k] - rest_pts[k - 1])).tolist() if k else [0.0, 0.0, 0.0]
        js["nodes"].append(node)
        idx = len(js["nodes"]) - 1
        js["nodes"][parent].setdefault("children", []).append(idx)
        js["skins"][0]["joints"].append(idx)
        world = np.eye(4)
        world[:3, :3], world[:3, 3] = r0, rest_pts[k]
        ibm.append(np.linalg.inv(world).T.reshape(16))
        parent = idx
    old = n.floats(js, b, js["skins"][0]["inverseBindMatrices"])
    js["skins"][0]["inverseBindMatrices"] = out.add_floats(np.concatenate([old, np.array(ibm)]), "MAT4")
    return first


def add_tail_clips(js, out, baked, first):
    for a, (times, keys) in zip(js["animations"], baked):
        tin = out.add_floats(times, "SCALAR")
        for k in range(len(CHAIN_Y)):
            smp = {"input": tin, "output": out.add_floats(keys[:, k], "VEC4"), "interpolation": "LINEAR"}
            a["samplers"].append(smp)
            node = js["skins"][0]["joints"][first + k]
            a["channels"].append({"sampler": len(a["samplers"]) - 1, "target": {"node": node, "path": "rotation"}})


def build(out_path, in_path):
    rig = rs.Rig(in_path)
    out = n.Out(rig.js, rig.b)
    blade = drop_blade(rig.js, rig.b, out)
    soften_lunge(rig.js, rig.b, out)
    rs.compact(out)
    out.write(out_path)  # (each stage writes and reloads: a new index array lives in the new file's buffer)
    rig = rs.Rig(out_path)
    out = n.Out(rig.js, rig.b)
    gone = drop_islands(rig.js, rig.b, out)
    rs.compact(out)
    out.write(out_path)  # the cleaned body first: the chain stage reads the new index arrays from the file
    rig = rs.Rig(out_path)
    js, b = rig.js, rig.b
    out = n.Out(js, b)
    gv = goo_vertices(js, b)
    prims = js["meshes"][0]["primitives"]
    pos = n.floats(js, b, prims[0]["attributes"]["POSITION"])
    _, joints, weights = rig.verts(0)
    hand = rest_world(rig, HAND)[1]
    rest_pts = chain_points(pos[gv], hand)
    ys = rest_pts[:-1, 1]
    baked = [tail_keys(rig, a["name"], rest_pts) for a in js["animations"]]  # before the new joints exist
    first = add_chain(js, b, out, rig, rest_pts)
    nj, nw = rs.top4(rs.dense(joints, weights, first + len(CHAIN_Y)))
    gj, gw = new_goo_weights(joints[gv], weights[gv], pos[gv], first, ys)
    nj[gv], nw[gv] = gj, gw
    view = out.add_view(nj.astype(np.uint16).tobytes())
    js["accessors"].append({"bufferView": view, "componentType": 5123, "count": len(nj), "type": "VEC4"})
    jacc, wacc = len(js["accessors"]) - 1, out.add_floats(nw, "VEC4")
    for p in prims[:2]:
        p["attributes"]["JOINTS_0"], p["attributes"]["WEIGHTS_0"] = jacc, wacc
    add_tail_clips(js, out, baked, first)
    rs.compact(out)
    out.write(out_path)
    print(f"heel crescent {blade} tris, {gone[0]} islands ({gone[1]} tris), chain at {np.round(ys, 2).tolist()}")
    print("written", out_path)


if __name__ == "__main__":
    if sys.argv[1] == "--islands":
        count_islands(sys.argv[2])
    else:
        build(sys.argv[1], sys.argv[2])
