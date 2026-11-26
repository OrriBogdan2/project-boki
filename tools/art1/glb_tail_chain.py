"""Turns the rigid tail bone of a .glb (made by tools/art1/glb_tail_bone.py) into a bending chain, with no Blender.
Made 11-26 for Meeko round 14: one rigid bone could only swing the whole hanging tail, so lifting it clear of the legs
made it a horizontal club. The chain lets the tail droop from the root, sweep back low and curl its tip up, like the ref.
Each tail vertex gets a parameter u = geodesic distance over the (welded) tail surface from the bone head, 0 at the root,
1 at the tip. Two child bones (NAME1, NAME2) sit at the tail's centreline at u = --joints; the weight ramps across each
joint over +-(--blend) in u, so there is no step. Every clip is re-keyed on the three bones: a pitch about the lateral axis
(+ = back and up) per bone (--pitch ROOT,MID,TIP, per clip with --pitch-clip Attack=35/20/30,...; an optional 4th value
RUN=15/0/45/30 sets that clip's root yaw), a root yaw (--yaw)
and a side sway that lags down the chain (--sway DEG,SECONDS; the period is fitted to a whole number per clip so loops
stay seamless). Where a frame still brings the tail within --gap m of a shin/foot or under --ground m, the root pitch
rises in 5 degree steps (up to --cap) for that frame, then the lift is eased over neighbouring frames.
The mesh, the paint, the other bones and their tracks stay byte for byte.

  python3 tools/art1/glb_tail_chain.py IN.glb OUT.glb [--bone Tail] [--joints 0.35,0.68] [--blend 0.08]
      [--pitch 25,15,25] [--pitch-clip Attack=35/20/30] [--yaw 12] [--sway 6,1.2] [--gap 0.025] [--ground 0.01] [--cap 60]
"""

import argparse
import sys

import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import dijkstra
from scipy.spatial import cKDTree

HERE = __file__.rsplit("/", 1)[0]
sys.path.insert(0, HERE)
sys.path.insert(0, HERE + "/../anim")
import geo_check as G  # noqa: E402
from glb_add_clips import prune, read, write  # noqa: E402
from glb_tail_bone import acc, add_acc, qaxis, qmul, world_rot_t  # noqa: E402

LEGS = ("LeftLeg", "RightLeg", "LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase")


def smooth(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


def tail_param(P, tris, tail, head):
    """u in [0,1] per tail vertex: geodesic distance over the welded tail surface from the vertices nearest the head."""
    key = np.round(P / 1e-5).astype(np.int64)
    _, weld = np.unique(key, axis=0, return_inverse=True)
    weld = weld.ravel()
    t = tris[tail[tris].all(1)]
    e = np.vstack([t[:, [0, 1]], t[:, [1, 2]], t[:, [2, 0]]])
    a, b = weld[e[:, 0]], weld[e[:, 1]]
    ln = np.linalg.norm(P[e[:, 0]] - P[e[:, 1]], axis=1) + 1e-9
    n = weld.max() + 1
    g = coo_matrix((ln, (a, b)), shape=(n, n)).tocsr()
    ids = np.where(tail)[0]
    dh = np.linalg.norm(P[ids] - head, axis=1)
    roots = np.unique(weld[ids[dh < dh.min() + 0.03]])
    d = dijkstra(g, directed=False, indices=roots, min_only=True)[weld]
    ok = tail & np.isfinite(d)
    lost = tail & ~ok  # bits not joined to the root surface take their nearest joined vertex's distance
    if lost.any():
        _, nn = cKDTree(P[ok]).query(P[lost])
        d[lost] = d[ok][nn]
    u = np.zeros(len(P))
    u[tail] = np.clip(d[tail] / np.percentile(d[tail], 98), 0, 1)
    return u


def mat(q, t):
    m = np.eye(4)
    m[:3, :3] = G.quat_to_mat(np.asarray(q, float)[None])[0]
    m[:3, 3] = t
    return m


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--bone", default="Tail")
    ap.add_argument("--joints", default="0.35,0.68")
    ap.add_argument("--blend", type=float, default=0.08)
    ap.add_argument("--pitch", default="25,15,25")
    ap.add_argument("--pitch-clip", default="")
    ap.add_argument("--yaw", type=float, default=12)
    ap.add_argument("--sway", default="6,1.2")
    ap.add_argument("--gap", type=float, default=0.025)
    ap.add_argument("--ground", type=float, default=0.01)
    ap.add_argument("--cap", type=float, default=60)
    ap.add_argument("--mat", default="Material_0")
    a = ap.parse_args()
    j, b = read(a.src)
    names = {n.get("name"): i for i, n in enumerate(j["nodes"])}
    ti = names[a.bone]
    pi = next(i for i, n in enumerate(j["nodes"]) if ti in n.get("children", []))
    tq, head = world_rot_t(j, ti)
    if abs(abs(tq[3]) - 1) > 1e-5:
        raise SystemExit("%s rest world rotation is not identity; not handled" % a.bone)
    pq, _ = world_rot_t(j, pi)
    pinv = np.array([-pq[0], -pq[1], -pq[2], pq[3]])
    mesh_node = next(n for n in j["nodes"] if "mesh" in n and "skin" in n)
    sk = j["skins"][mesh_node["skin"]]
    tj = sk["joints"].index(ti)
    mats = [m.get("name") for m in j["materials"]]
    pr = next(p for p in j["meshes"][mesh_node["mesh"]]["primitives"] if mats[p["material"]] == a.mat)
    P = acc(j, b, pr["attributes"]["POSITION"]).astype(np.float64)
    J = acc(j, b, pr["attributes"]["JOINTS_0"]).astype(np.int64)
    W = acc(j, b, pr["attributes"]["WEIGHTS_0"]).astype(np.float64)
    tris = acc(j, b, pr["indices"]).astype(np.int64).reshape(-1, 3)
    tw = (W * (J == tj)).sum(1)
    tail = tw > 0.01
    u = tail_param(P, tris, tail, head)
    uj = [float(x) for x in a.joints.split(",")]
    jpos = [P[tail & (np.abs(u - x) < 0.03)].mean(0) for x in uj]
    print("tail verts %d, joints at u %s -> %s" % (tail.sum(), uj, [np.round(p, 3).tolist() for p in jpos]))
    # bones: children of the tail bone, rest world rotation identity like it
    new, prev, prev_pos = [], ti, head
    ibm = acc(j, b, sk["inverseBindMatrices"]).copy()
    for k, p in enumerate(jpos, 1):
        j["nodes"].append({"name": "%s%d" % (a.bone, k), "translation": (p - prev_pos).tolist()})
        ni = len(j["nodes"]) - 1
        j["nodes"][prev].setdefault("children", []).append(ni)
        m = np.eye(4, dtype=np.float32)
        m[:3, 3] = -p
        ibm = np.vstack([ibm, m.T.reshape(1, 16)])
        sk["joints"].append(ni)
        new.append(ni)
        prev, prev_pos = ni, p
    sk["inverseBindMatrices"] = add_acc(j, b, ibm.astype(np.float32), 5126, "MAT4")
    # weights: tail weight split across the chain by u
    a1 = smooth((u - uj[0] + a.blend) / (2 * a.blend))
    a2 = smooth((u - uj[1] + a.blend) / (2 * a.blend))
    full = np.zeros((len(P), len(sk["joints"])))
    for k in range(4):
        np.add.at(full, (np.arange(len(P)), J[:, k]), W[:, k])
    full[:, tj] = tw * (1 - a1)
    full[:, len(sk["joints"]) - 2] = tw * (a1 - a2)
    full[:, len(sk["joints"]) - 1] = tw * a2
    top = np.argsort(-full, 1)[:, :4]
    ww = np.take_along_axis(full, top, 1)
    ww /= ww.sum(1, keepdims=True)
    ww[ww < 1e-6] = 0
    pr["attributes"]["JOINTS_0"] = add_acc(j, b, top.astype(np.uint16), 5123, "VEC4")
    pr["attributes"]["WEIGHTS_0"] = add_acc(j, b, ww.astype(np.float32), 5126, "VEC4")
    print("weights: root %d, mid %d, tip %d verts (w>0.5)" % ((full[:, tj] > 0.5).sum(), (full[:, -2] > 0.5).sum(),
                                                              (full[:, -1] > 0.5).sum()))
    keys(a, j, b, P, full, tail, pi, ti, new, pinv, [head] + jpos)
    j["buffers"][0]["byteLength"] = len(b)
    write(a.dst, j, prune(j, b))


def keys(a, j, b, P, full, tail, pi, ti, new, pinv, heads):
    """Re-keys the chain in every clip, lifting the root where the tail would touch a shin/foot or the ground."""
    rig = G.Rig(j, bytes(b))
    m = G.load_mesh(j, bytes(b))
    hj = rig.names.index(j["nodes"][pi]["name"])
    dom = np.array(rig.names)[m["joints"][np.arange(len(m["pos"])), m["weights"].argmax(1)]]
    legs = np.where(np.isin(dom, LEGS))[0][::2]
    tid = np.where(tail)[0][::3]
    bones = [ti] + new
    tw = full[tid][:, [rig.joints.index(i) for i in bones]]
    hom = [np.c_[P[tid] - h, np.ones(len(tid))] for h in heads]
    base = [float(x) for x in a.pitch.split(",")]
    per = {k: [float(x) for x in v.split("/")] for k, v in (kv.split("=") for kv in a.pitch_clip.split(",") if kv)}
    sdeg, sper = (float(x) for x in a.sway.split(","))
    lat, up = np.array([1.0, 0, 0]), np.array([0, 1.0, 0])
    for an in j["animations"]:
        an["channels"] = [c for c in an["channels"] if c["target"]["node"] != ti]
        hs = next((c for c in an["channels"] if c["target"]["node"] == pi), None)
        times = acc(j, b, an["samplers"][hs["sampler"]]["input"])[:, 0].copy() if hs else np.array([0.0, 1.0], np.float32)
        length = max(float(times.max()), 1e-3)
        period = length / max(1, round(length / sper))
        pitch = per.get(an["name"], base)
        yaw = pitch[3] if len(pitch) > 3 else a.yaw  # optional 4th value: this clip's root yaw
        sway = [sdeg * (1 + 0.5 * k) * np.sin(2 * np.pi * times / period - 0.9 * k) for k in range(3)]

        def local(k, f, extra):
            qw = qmul(qaxis(up, sway[k][f] + (yaw if k == 0 else 0)), qaxis(lat, pitch[k] + (extra if k == 0 else 0)))
            return qmul(pinv, qw) if k == 0 else qw

        S = rig.skin_mats(an, times.astype(float))
        lift = np.zeros(len(times))
        for f in range(len(times)):
            wh = S[f, hj] @ np.linalg.inv(rig.ibm[hj])
            pl, _ = G.skin_points(S[f], m, legs)
            tree = cKDTree(pl)
            for extra in np.arange(0, a.cap + 1, 5):
                pt = np.zeros((len(tid), 3))
                w = wh @ mat(local(0, f, extra), rig.rest[ti][0])
                for k in range(3):
                    if k:
                        w = w @ mat(local(k, f, 0), rig.rest[new[k - 1]][0])
                    pt += tw[:, k, None] * (hom[k] @ w.T)[:, :3]
                if tree.query(pt)[0].min() >= a.gap and pt[:, 1].min() >= a.ground:
                    break
            lift[f] = extra
        n = len(lift)
        lift = np.array([lift[max(0, i - 2):i + 3].max() for i in range(n)])
        lift = np.array([lift[max(0, i - 2):i + 3].mean() for i in range(n)])
        for k, node in enumerate(bones):
            q = np.array([local(k, f, lift[f]) for f in range(n)], np.float32)
            ti_ = add_acc(j, b, times.astype(np.float32).reshape(-1, 1), 5126, "SCALAR", True)
            oi = add_acc(j, b, q, 5126, "VEC4")
            an["samplers"].append({"input": ti_, "output": oi, "interpolation": "LINEAR"})
            an["channels"].append({"sampler": len(an["samplers"]) - 1, "target": {"node": node, "path": "rotation"}})
        print("clip %s: %d keys, pitch %s yaw %.0f, lift max %.0f mean %.1f" % (an["name"], n, pitch[:3], yaw, lift.max(), lift.mean()))


if __name__ == "__main__":
    main()
