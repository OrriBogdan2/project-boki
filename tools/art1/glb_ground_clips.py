"""Keeps a Meshy-native hunter's feet and tail on top of the ground in every clip (keys only).

Meshy's clips often sink the planted foot a few cm under y=0 (Meeko: Idle -3.3 cm, Attack -7.6 cm median), so in game
the paws vanish into the floor, and a long tail drags through it (Meeko Idle -8 cm every frame, Attack -33 cm).
1. feet: per clip, the root bone's translation keys are lifted by how far the lowest foot vertex is under the floor
   (a running max over +-`--win` keys, then a moving average so there is no pop). Never lowered.
2. tail: the tail root bone gets per-key rotations (keyed at the root's translation key times) that pitch the tail up
   about the axis across it until its lowest vertex is `--tail-floor` above the ground; smoothed the same way.
Mesh, skin, textures and every other track stay byte-identical; new tail keys are appended as new accessors.
Run: python3 tools/art1/glb_ground_clips.py IN.glb OUT.glb --root=Hips --feet=LeftFoot,LeftToeBase,LeftLeg,...
     --tail=Bone_013 --tail-bones=Bone_013,Bone_012,Bone_011 [--floor=0.003] [--tail-floor=0.01] [--tail-max=60] [--clips=A,B]
     [--report]  (only print the per-clip numbers, write nothing)
"""

import argparse
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "anim"))
from glb_add_clips import read, write  # noqa: E402
import geo_check as gc  # noqa: E402


def aa(ax, rad):
    ax = np.asarray(ax, float) / np.linalg.norm(ax)
    return np.r_[ax * np.sin(rad / 2), np.cos(rad / 2)]


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


def smooth_up(v, win, loop):
    """Running max over +-win, then a +-win moving average: never far under the need, no pop."""
    n = len(v)
    if n < 3 or win < 1:
        return v.copy()
    pad = (lambda x: np.r_[x[-win:], x, x[:win]]) if loop else (lambda x: np.r_[[x[0]] * win, x, [x[-1]] * win])
    p = pad(v)
    mx = np.array([p[i : i + 2 * win + 1].max() for i in range(n)])
    p = pad(mx)
    return np.array([p[i : i + 2 * win + 1].mean() for i in range(n)])


def channel(j, anim, node, path):
    for c in anim["channels"]:
        if c["target"]["node"] == node and c["target"]["path"] == path:
            return c, anim["samplers"][c["sampler"]]
    return None, None


def acc_view(j, ai):
    a = j["accessors"][ai]
    bv = j["bufferViews"][a["bufferView"]]
    return bv.get("byteOffset", 0) + a.get("byteOffset", 0), a["count"]


def append_acc(j, b, arr, typ):
    arr = np.ascontiguousarray(arr, "<f4")
    b = bytearray(bytes(b) + b"\0" * (-len(b) % 4))  # a fresh buffer: numpy views pin the old one
    off = len(b)
    b += arr.tobytes()
    j["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": arr.nbytes})
    acc = {"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126, "count": len(arr), "type": typ}
    if typ == "SCALAR":
        acc["min"], acc["max"] = [float(arr.min())], [float(arr.max())]
    j["accessors"].append(acc)
    j["buffers"][0]["byteLength"] = len(b)
    return b, len(j["accessors"]) - 1


def lowest(rig, mesh, anim, T, ids):
    S = rig.skin_mats(anim, T)
    return np.array([gc.skin_points(S[f], mesh, ids)[0][:, 1].min() for f in range(len(T))])


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--root", default="Hips")
    ap.add_argument("--feet", required=True)
    ap.add_argument("--tail")
    ap.add_argument("--tail-bones", default="")
    ap.add_argument("--floor", type=float, default=0.003)
    ap.add_argument("--tail-floor", type=float, default=0.01)
    ap.add_argument("--tail-max", type=float, default=60.0, help="most tail pitch, deg (a big flick hides the back)")
    ap.add_argument("--win", type=int, default=2)
    ap.add_argument("--clips", default="")
    ap.add_argument("--no-loop", default="Jump_Run,Attack", help="clips smoothed without wrap-around")
    ap.add_argument("--report", action="store_true")
    a = ap.parse_args(argv)
    j, b = read(a.src)
    rig = gc.Rig(j, b)
    mesh = gc.load_mesh(j, b)
    nodes = j["nodes"]
    idx = {nd["name"]: i for i, nd in enumerate(nodes)}
    dom = mesh["joints"][np.arange(len(mesh["pos"])), mesh["weights"].argmax(1)]
    dom_name = np.array([nodes[rig.joints[k]]["name"] for k in dom])
    feet = np.where(np.isin(dom_name, a.feet.split(",")))[0]
    tail = np.where(np.isin(dom_name, a.tail_bones.split(",")))[0] if a.tail else np.array([], int)
    root = idx[a.root]
    no_loop = set(a.no_loop.split(","))
    for anim in j["animations"]:
        if a.clips and anim["name"] not in a.clips.split(","):
            continue
        loop = anim["name"] not in no_loop
        _, ts = channel(j, anim, root, "translation")
        off_t, n_t = acc_view(j, ts["output"])
        T = gc.accessor(j, b, ts["input"])[:, 0].astype(float)
        tr = np.frombuffer(bytes(b[off_t : off_t + 12 * n_t]), "<f4").reshape(-1, 3).astype(float)
        low0 = lowest(rig, mesh, anim, T, feet)
        lift = smooth_up(np.maximum(0.0, a.floor - low0), a.win, loop)
        line = f"{anim['name']:24s} feet low median {np.median(low0) * 100:+5.1f} min {low0.min() * 100:+5.1f} cm"
        if not a.report:
            # model space is the armature's space (identity here): the root's parent must not rotate/scale
            tr2 = tr.copy()
            tr2[:, 1] += lift
            b[off_t : off_t + 12 * n_t] = tr2.astype("<f4").tobytes()
            low1 = lowest(rig, mesh, anim, T, feet)
            line += f" -> lift max {lift.max() * 100:4.1f} cm, low median {np.median(low1) * 100:+5.1f} min {low1.min() * 100:+5.1f}"
        if len(tail):
            tn = idx[a.tail]
            tlow0 = lowest(rig, mesh, anim, T, tail)
            line += f" | tail min {tlow0.min() * 100:+5.1f} cm, under {np.mean(tlow0 < 0) * 100:3.0f}% keys"
            if not a.report and tlow0.min() < a.tail_floor:
                c, s = channel(j, anim, tn, "rotation")
                q_in = gc.channel_at(
                    gc.accessor(j, b, s["input"])[:, 0].astype(float),
                    gc.accessor(j, b, s["output"]).astype(float),
                    s.get("interpolation", "LINEAR"),
                    "rotation",
                    T,
                )
                ang = np.zeros(len(T))
                parent = rig.parent[tn]
                jpar = rig.joints.index(parent)
                ibm_inv_p = np.linalg.inv(rig.ibm[jpar])
                ibm_inv_t = np.linalg.inv(rig.ibm[rig.joints.index(tn)])
                b, ti = append_acc(j, b, T, "SCALAR")
                b, qo = append_acc(j, b, q_in, "VEC4")
                rig.bin = b
                s["input"], s["output"], s["interpolation"] = ti, qo, "LINEAR"
                off_q, _ = acc_view(j, qo)
                for _it in range(40):
                    S = rig.skin_mats(anim, T)
                    lowt = np.array([gc.skin_points(S[f], mesh, tail)[0][:, 1].min() for f in range(len(T))])
                    need = (lowt < a.tail_floor) & (ang < np.radians(a.tail_max) - 1e-6)
                    if not need.any():
                        break
                    ang = np.minimum(
                        smooth_up(np.where(need, ang + np.radians(2), ang), 1, loop), np.radians(a.tail_max)
                    )
                    new = []
                    for f in range(len(T)):
                        Gp = S[f, jpar] @ ibm_inv_p
                        Gt = S[f, rig.joints.index(tn)] @ ibm_inv_t
                        Rp = Gp[:3, :3] / np.linalg.norm(Gp[:3, :3], axis=0)
                        piv = Gt[:3, 3]
                        cen = gc.skin_points(S[f], mesh, tail)[0].mean(0) - piv
                        ax_w = np.cross(cen, [0, 1, 0])
                        if np.linalg.norm(ax_w) < 1e-6:
                            ax_w = np.array([1.0, 0, 0])
                        ax_l = Rp.T @ (ax_w / np.linalg.norm(ax_w))
                        new.append(qmul(aa(ax_l, ang[f]), q_in[f]))
                    # recompute from the original keys each pass, so the axis follows the current pose only once
                    b[off_q : off_q + 16 * len(T)] = np.array(new, "<f4").tobytes()
                tlow1 = lowest(rig, mesh, anim, T, tail)
                line += f" -> pitch max {np.degrees(ang.max()):4.1f} deg, tail min {tlow1.min() * 100:+5.1f} cm"
        print(line)
    if not a.report:
        write(a.dst, j, b)


if __name__ == "__main__":
    main(sys.argv[1:])
