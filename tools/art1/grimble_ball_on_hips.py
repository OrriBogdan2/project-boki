"""Grimble's junk ball rides his hips (was: the root bone), with no Blender.
Why: the ball bone hung off `root`, which a run barely pitches, while the hips and spine lean a run forward up to 40
degrees (more with the gait lean): at a run the ball hung in the air above and behind him, "a dark ball floating over
his head" (owner 11-19). Its rest pose and every clip that holds it at rest now follow the hips; `lunge`, `lunge_out`
and `pounce` (which roll the ball round him in root space) are re-keyed into the hips' space so they look the same.
Run once on the glb as committed before this change (git checkout it to redo):
    python3 tools/art1/grimble_ball_on_hips.py art/wardens/dredge/dredge.glb [out.glb]"""
import sys

import numpy as np

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from grimble_barge_clips import read, write  # noqa: E402

HOLD_EPS = 1e-4     # a ball track that moves less than this (m or quaternion units) over a clip is "held at rest"


def quat_mat(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def mat_quat(m):
    t = m[0, 0] + m[1, 1] + m[2, 2]
    if t > 0:
        s = 2 * np.sqrt(t + 1)
        q = [(m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s, s / 4]
    else:
        i = int(np.argmax(np.diag(m)))
        a, b = (i + 1) % 3, (i + 2) % 3
        s = 2 * np.sqrt(1 + m[i, i] - m[a, a] - m[b, b])
        q = [0, 0, 0, 0]
        q[i] = s / 4
        q[a] = (m[a, i] + m[i, a]) / s
        q[b] = (m[b, i] + m[i, b]) / s
        q[3] = (m[b, a] - m[a, b]) / s
    return np.array(q) / np.linalg.norm(q)


def trs(t, q):
    m = np.eye(4)
    m[:3, :3] = quat_mat(q)
    m[:3, 3] = t
    return m


def accessor(j, bin_, i):
    ac = j["accessors"][i]
    v = j["bufferViews"][ac["bufferView"]]
    nc = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[ac["type"]]
    o = v.get("byteOffset", 0) + ac.get("byteOffset", 0)
    raw = np.frombuffer(bytes(bin_[o:o + 4 * ac["count"] * nc]), dtype="<f4")
    return ac, o, raw.reshape(ac["count"], nc).astype(float)


def pose_at(j, bin_, an, node, t, rest):
    """The node's local (translation, rotation) in clip `an` at time t (linear; rest where it has no track)."""
    out = dict(rest)
    for ch in an["channels"]:
        if ch["target"].get("node") != node or ch["target"]["path"] not in out:
            continue
        smp = an["samplers"][ch["sampler"]]
        times = accessor(j, bin_, smp["input"])[2].ravel()
        vals = accessor(j, bin_, smp["output"])[2]
        out[ch["target"]["path"]] = np.array([np.interp(t, times, vals[:, k]) for k in range(vals.shape[1])])
    return out


def build(j, bin_):
    nodes = j["nodes"]
    idx = {n["name"]: i for i, n in enumerate(nodes)}
    ball, hips = idx["ball"], idx["hips"]
    rest_h = {"translation": np.array(nodes[hips]["translation"]), "rotation": np.array(nodes[hips]["rotation"])}
    hips_m = trs(rest_h["translation"], rest_h["rotation"])
    ball_m = trs(nodes[ball]["translation"], nodes[ball]["rotation"])
    new_m = np.linalg.inv(hips_m) @ ball_m
    new_t, new_q = new_m[:3, 3], mat_quat(new_m[:3, :3])
    for n in nodes:
        if ball in n.get("children", []):
            n["children"].remove(ball)
    nodes[hips]["children"].append(ball)
    nodes[ball]["translation"] = [float(x) for x in new_t]
    nodes[ball]["rotation"] = [float(x) for x in new_q]
    rest_b = {"translation": np.array(new_m[:3, 3]), "rotation": np.array(new_q)}
    old_b = {"translation": np.array(ball_m[:3, 3]), "rotation": np.array(mat_quat(ball_m[:3, :3]))}
    for an in j["animations"]:
        writes = []
        for ch in an["channels"]:
            path = ch["target"]["path"]
            if ch["target"].get("node") != ball or path == "scale":
                continue
            smp = an["samplers"][ch["sampler"]]
            _, o, vals = accessor(j, bin_, smp["output"])
            times = accessor(j, bin_, smp["input"])[2].ravel()
            if np.ptp(vals, axis=0).max() < HOLD_EPS:
                new = np.tile(rest_b[path], (len(vals), 1))
            else:
                # keyed in root space: each key becomes the hips' space at that time (the clip's own hips pose)
                new = np.zeros_like(vals)
                for k, t in enumerate(times):
                    own = pose_at(j, bin_, an, ball, t, old_b)
                    hp = pose_at(j, bin_, an, hips, t, rest_h)
                    hips_now = trs(hp["translation"], hp["rotation"])
                    m = np.linalg.inv(hips_now) @ trs(own["translation"], own["rotation"])
                    new[k] = m[:3, 3] if path == "translation" else mat_quat(m[:3, :3])
            if path == "rotation":
                for k in range(1, len(new)):
                    if new[k] @ new[k - 1] < 0:      # one hemisphere, so a key never turns the long way round
                        new[k] = -new[k]
            writes.append((o, new))
        for o, new in writes:
            bin_[o:o + new.size * 4] = new.astype("<f4").tobytes()
    return j, bin_


if __name__ == "__main__":
    src = sys.argv[1]
    j, bin_ = read(src)
    j, bin_ = build(j, bin_)
    write(sys.argv[2] if len(sys.argv) > 2 else src, j, bin_)
