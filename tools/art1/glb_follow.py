"""Hangs a bone that the clips leave standing in the air under another bone, in a shipped Hero .glb, with no Blender.

Grimble's junk ball was a loose bone under the armature root: it sits at the back of his pack at rest, but only the barge
clips (lunge, lunge_out, pounce) key it, every other clip holds its rest pose, so in a run or a crouch the body dips and
leans and the ball hung where he was. Here the ball node becomes a child of the bone the pack's skin rides (`head`): its
rest pose is carried into that bone's frame, a clip that holds it still keeps it still there (it rides the pack), and a
clip that keys it (any key moving by more than TOL) keeps the world track it had (its keys are re-expressed in the new
parent's frame, per key). The game wants the same parent in the Hero's `extra_bones` (content/rules/warden_anim/<art>.json:
WardenSkeleton.mismatches refuses a model whose variant bone has another parent and keeps the procedural one).
Run: python3 tools/art1/glb_follow.py <in.glb> <out.glb> <follower node> <leader node>   (numpy only)
v95_swap.py runs it for a spec's `follow` {follower: leader}."""

import struct
import sys

import numpy as np

import glb_add_clips
from glb_relax import accessor, local_matrix, sample

TOL = 1e-4  # a follower track that moves by more than this (m, or quaternion units) is keyed by the clip


def matrix_quat(m):
    """Quaternion (x, y, z, w) of the rotation in the top-left of a 4x4 (scale divided out)."""
    r = m[:3, :3] / np.linalg.norm(m[:3, :3], axis=0)
    t = np.trace(r)
    if t > 0:
        s = 2 * np.sqrt(t + 1)
        q = [(r[2, 1] - r[1, 2]) / s, (r[0, 2] - r[2, 0]) / s, (r[1, 0] - r[0, 1]) / s, s / 4]
    else:
        i = int(np.argmax(np.diag(r)))
        a, b = (i + 1) % 3, (i + 2) % 3
        s = 2 * np.sqrt(1 + r[i, i] - r[a, a] - r[b, b])
        q = [0.0] * 4
        q[i] = s / 4
        q[a] = (r[a, i] + r[i, a]) / s
        q[b] = (r[b, i] + r[i, b]) / s
        q[3] = (r[b, a] - r[a, b]) / s
    q = np.array(q)
    return q / np.linalg.norm(q)


def follow(j, bin_, follower, leader):
    """Makes `follower` a child of `leader` (its world pose at rest is unchanged) and re-expresses its clip keys in the
    leader's frame. Appends the new keys to bin_. Returns the names of the clips rewritten (a * after those that key it)."""
    nodes = j["nodes"]
    idx = {n["name"]: i for i, n in enumerate(nodes) if "name" in n}
    fo, le = idx[follower], idx[leader]
    parent = {c: i for i, n in enumerate(nodes) for c in n.get("children", [])}
    assert fo in parent and parent[fo] != le, "follower must hang under another node"
    rest = [
        {"translation": list(n.get("translation", [0, 0, 0])), "rotation": list(n.get("rotation", [0, 0, 0, 1])),
         "scale": list(n.get("scale", [1, 1, 1]))}
        for n in nodes
    ]

    def world(i, trs):
        m = local_matrix(trs[i])
        return world(parent[i], trs) @ m if i in parent else m

    old_up = world(parent[fo], rest)
    rest_local = np.linalg.inv(world(le, rest)) @ old_up @ local_matrix(rest[fo])
    nodes[parent[fo]]["children"].remove(fo)
    nodes[le].setdefault("children", []).append(fo)
    parent[fo] = le
    nodes[fo]["translation"] = [float(x) for x in rest_local[:3, 3]]
    nodes[fo]["rotation"] = [float(x) for x in matrix_quat(rest_local)]
    nodes[fo]["scale"] = [float(np.linalg.norm(rest_local[:3, c])) for c in range(3)]
    rest[fo] = {"translation": nodes[fo]["translation"], "rotation": nodes[fo]["rotation"], "scale": nodes[fo]["scale"]}
    changed = []
    for anim in j["animations"]:
        tracks = {ch["target"]["path"]: ch for ch in anim["channels"] if ch["target"].get("node") == fo}
        if not tracks:
            continue
        chans = []
        for ch in anim["channels"]:
            smp = anim["samplers"][ch["sampler"]]
            if ch["target"]["path"] in ("translation", "rotation", "scale"):
                chans.append((ch["target"]["node"], ch["target"]["path"], accessor(j, bin_, smp["input"])[0][:, 0].astype(float),
                              accessor(j, bin_, smp["output"])[0].astype(float), smp.get("interpolation", "LINEAR")))
        held = all(float(np.ptp(c[3], axis=0).max()) < TOL for c in chans if c[0] == fo and c[1] != "scale")
        for p in ("translation", "rotation", "scale"):
            if p not in tracks:
                continue
            smp = anim["samplers"][tracks[p]["sampler"]]
            times = accessor(j, bin_, smp["input"])[0][:, 0].astype(float)
            out = []
            for t in times:
                if held:
                    out.append(np.array(rest[fo][p]))
                    continue
                trs = [dict(r) for r in rest]
                for node, path, ts, vs, mode in chans:
                    trs[node][path] = sample(ts, vs, mode, path, t)
                loc = np.linalg.inv(world(le, trs)) @ old_up @ local_matrix(trs[fo])
                out.append(loc[:3, 3] if p == "translation" else matrix_quat(loc) if p == "rotation" else np.linalg.norm(loc[:3, :3], axis=0))
            out = np.array(out, np.float32)
            if p == "rotation":  # one hemisphere along the clip
                for k in range(1, len(out)):
                    if np.dot(out[k], out[k - 1]) < 0:
                        out[k] = -out[k]
            while len(bin_) % 4:
                bin_.append(0)
            j["bufferViews"].append({"buffer": 0, "byteOffset": len(bin_), "byteLength": out.nbytes})
            bin_ += out.tobytes()
            old = j["accessors"][smp["output"]]
            j["accessors"].append({"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126, "count": len(out), "type": old["type"]})
            smp["output"] = len(j["accessors"]) - 1
        changed.append(anim["name"] + ("" if held else "*"))
    return changed


def main():
    src, dst, follower, leader = sys.argv[1:5]
    j, bin_ = glb_add_clips.read(src)
    changed = follow(j, bin_, follower, leader)
    j["buffers"][0]["byteLength"] = len(bin_)
    glb_add_clips.write(dst, j, bin_)
    print("glb_follow: %s rides %s in %d clips" % (follower, leader, len(changed)))


if __name__ == "__main__":
    main()
