"""Gives a body whose tail is skinned rigid to the hips its own tail bone, keyed back/up in every clip, with no Blender.
Made 11-26 for Meeko round 13: the r12 Meshy upload rig put the tail on the legs, so it was moved to Hips, and it then
hung to the ground right behind the legs (every leg swing went into it). The tail weight per vertex comes from another
rig of the SAME mesh that has a tail chain (Meshy's task-id rig, saved as an npz of glTF-frame positions P and chain
weights W); nearest vertex within --reach m, then averaged over neighbours within --smooth m. Only vertices whose
dominant bone is --parent take tail weight (the legs keep theirs, even where the tail touches them).
The new bone (rest world rotation = identity, head at --head) is a child of --parent; the vertex's weight moves onto it
as (1 - w) * old + w * bone (top 4 kept). Each clip gets a rotation track: about the parent's lateral axis by --pitch
degrees (+ = tail back and up), then --yaw degrees about its up axis (+ = a tail curled to the left swings back), plus an optional side sway (--sway DEG,SECONDS) for life. The clips, the other bones,
every other primitive and the paint stay byte for byte.

  python3 tools/art1/glb_tail_bone.py IN.glb OUT.glb --weights tail.npz --head x,y,z [--parent Hips] [--name Tail]
      [--pitch 40] [--yaw 0] [--sway 0,1] [--reach 0.03] [--smooth 0.02] [--mat Material_0] [--pitch-clip Attack=30,...]
"""

import argparse
import sys

import numpy as np
from scipy.spatial import cKDTree

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from glb_add_clips import prune, read, write  # noqa: E402


def qmul(a, b):
    x1, y1, z1, w1 = a
    x2, y2, z2, w2 = b
    return np.array(
        [
            w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
            w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
            w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2,
            w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2,
        ]
    )


def qrot(q, v):
    u = np.array(q[:3])
    return 2 * u.dot(v) * u + (q[3] ** 2 - u.dot(u)) * np.asarray(v) + 2 * q[3] * np.cross(u, v)


def qaxis(ax, deg):
    ax = np.asarray(ax, float) / np.linalg.norm(ax)
    h = np.radians(deg) / 2
    return np.append(ax * np.sin(h), np.cos(h))


def acc(j, b, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
    dt = {5126: "<f4", 5125: "<u4", 5123: "<u2", 5121: "u1"}[a["componentType"]]
    o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    if bv.get("byteStride"):
        raise SystemExit("strided accessor %d not handled" % i)
    return np.frombuffer(bytes(b[o : o + a["count"] * n * np.dtype(dt).itemsize]), dt).reshape(a["count"], n)


def add_acc(j, b, arr, ctype, typ, minmax=False):
    b.extend(b"\0" * (-len(b) % 4))
    j["bufferViews"].append({"buffer": 0, "byteOffset": len(b), "byteLength": arr.nbytes})
    b.extend(arr.tobytes())
    a = {"bufferView": len(j["bufferViews"]) - 1, "componentType": ctype, "count": len(arr), "type": typ}
    if minmax:
        a["min"], a["max"] = arr.min(0).tolist(), arr.max(0).tolist()
    j["accessors"].append(a)
    return len(j["accessors"]) - 1


def world_rot_t(j, ni):
    par = {c: i for i, n in enumerate(j["nodes"]) for c in n.get("children", [])}
    chain = [ni]
    while chain[-1] in par:
        chain.append(par[chain[-1]])
    q, t = np.array([0, 0, 0, 1.0]), np.zeros(3)
    for k in reversed(chain):
        n = j["nodes"][k]
        if "matrix" in n or any(abs(s - 1) > 1e-4 for s in n.get("scale", [1, 1, 1])):
            raise SystemExit("node %s has a matrix/scale; not handled" % n.get("name"))
        t = t + qrot(q, n.get("translation", [0, 0, 0]))
        q = qmul(q, n.get("rotation", [0, 0, 0, 1]))
    return q, t


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--weights", required=True)
    ap.add_argument("--head", required=True)
    ap.add_argument("--parent", default="Hips")
    ap.add_argument("--name", default="Tail")
    ap.add_argument("--pitch", type=float, default=40)
    ap.add_argument("--pitch-clip", default="")
    ap.add_argument("--sway", default="0,1")
    ap.add_argument("--yaw", type=float, default=0)
    ap.add_argument("--reach", type=float, default=0.03)
    ap.add_argument("--smooth", type=float, default=0.02)
    ap.add_argument("--mat", default="Material_0")
    a = ap.parse_args()
    j, b = read(a.src)
    names = {n.get("name"): i for i, n in enumerate(j["nodes"])}
    if a.name in names:
        raise SystemExit("%s already in %s" % (a.name, a.src))
    pi = names[a.parent]
    head = np.array([float(x) for x in a.head.split(",")])
    pq, pt = world_rot_t(j, pi)
    pinv = np.array([-pq[0], -pq[1], -pq[2], pq[3]])
    node = {"name": a.name, "translation": qrot(pinv, head - pt).tolist(), "rotation": pinv.tolist()}
    j["nodes"].append(node)
    ni = len(j["nodes"]) - 1
    j["nodes"][pi].setdefault("children", []).append(ni)
    # skin: joint + inverse bind (world rest = translation(head), so its inverse is translation(-head))
    mesh_node = next(n for n in j["nodes"] if "mesh" in n and "skin" in n)
    sk = j["skins"][mesh_node["skin"]]
    mq, mt = world_rot_t(j, j["nodes"].index(mesh_node))
    if np.abs(mt).max() > 1e-5 or abs(abs(mq[3]) - 1) > 1e-6:
        raise SystemExit("mesh node is not at the origin; not handled")
    ibm = acc(j, b, sk["inverseBindMatrices"]).copy()
    m = np.eye(4, dtype=np.float32)
    m[:3, 3] = -head
    ibm = np.vstack([ibm, m.T.reshape(1, 16)]).astype(np.float32)
    sk["inverseBindMatrices"] = add_acc(j, b, ibm, 5126, "MAT4")
    sk["joints"].append(ni)
    bj = len(sk["joints"]) - 1
    # weights
    src = np.load(a.weights)
    tree = cKDTree(src["P"])
    mats = [mt_.get("name") for mt_ in j["materials"]]
    for pr in j["meshes"][mesh_node["mesh"]]["primitives"]:
        if mats[pr["material"]] != a.mat:
            continue
        P = acc(j, b, pr["attributes"]["POSITION"]).astype(np.float64)
        J = acc(j, b, pr["attributes"]["JOINTS_0"]).astype(np.int64)
        W = acc(j, b, pr["attributes"]["WEIGHTS_0"]).astype(np.float64)
        d, idx = tree.query(P)
        w = np.where(d < a.reach, src["W"][idx], 0.0)
        if a.smooth > 0:
            own = cKDTree(P)
            nb = own.query_ball_point(P, a.smooth)
            w = np.array([w[n].mean() for n in nb])
        # only vertices the parent already carries (dominant bone): the legs keep their own skin
        pj = sk["joints"].index(pi)
        own_p = J[np.arange(len(J)), W.argmax(1)] == pj
        w = np.clip(w, 0, 1) * own_p
        if a.smooth > 0:  # second pass so the cut at the legs is a ramp, not a step
            w = np.array([w[n].mean() for n in nb]) * own_p
        full = np.zeros((len(P), bj + 1))
        for k in range(4):
            np.add.at(full, (np.arange(len(P)), J[:, k]), W[:, k])
        full *= (1 - w)[:, None]
        full[:, bj] += w
        top = np.argsort(-full, 1)[:, :4]
        tw = np.take_along_axis(full, top, 1)
        tw /= tw.sum(1, keepdims=True)
        tw[tw < 1e-6] = 0
        pr["attributes"]["JOINTS_0"] = add_acc(j, b, top.astype(np.uint16), 5123, "VEC4")
        pr["attributes"]["WEIGHTS_0"] = add_acc(j, b, tw.astype(np.float32), 5126, "VEC4")
        print("%s: %d verts, %d onto %s (w>0.5: %d)" % (a.mat, len(P), (w > 0.01).sum(), a.name, (w > 0.5).sum()))
    # clips
    lateral = qrot(pq, [1, 0, 0])  # the parent's lateral axis at rest, world
    up = qrot(pq, [0, 1, 0])
    per = dict(kv.split("=") for kv in a.pitch_clip.split(",") if kv)
    sdeg, sper = (float(x) for x in a.sway.split(","))
    for an in j["animations"]:
        times = None
        for ch in an["channels"]:
            if ch["target"]["node"] == pi:
                times = acc(j, b, an["samplers"][ch["sampler"]]["input"])[:, 0]
                break
        if times is None:
            times = np.array([0.0, 1.0], np.float32)
        pitch = float(per.get(an["name"], a.pitch))
        q = []
        for t in times:
            qw = qmul(qaxis(up, a.yaw + sdeg * np.sin(2 * np.pi * t / sper)), qaxis(lateral, pitch))
            q.append(qmul(pinv, qw))
        q = np.array(q, np.float32)
        ti = add_acc(j, b, times.astype(np.float32).reshape(-1, 1), 5126, "SCALAR", True)
        oi = add_acc(j, b, q, 5126, "VEC4")
        an["samplers"].append({"input": ti, "output": oi, "interpolation": "LINEAR"})
        an["channels"].append({"sampler": len(an["samplers"]) - 1, "target": {"node": ni, "path": "rotation"}})
        print("clip %s: %d keys, pitch %.0f" % (an["name"], len(times), pitch))
    j["buffers"][0]["byteLength"] = len(b)
    write(a.dst, j, prune(j, b))


if __name__ == "__main__":
    main()
