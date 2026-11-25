"""Pulls a limb back toward its rest hang in chosen clips of a .glb, with no Blender: every rotation key of the named bones
is slerped toward the bone's rest rotation by a fraction (0 = the clip as keyed, 1 = the rest pose), so the motion keeps
its rhythm at a smaller swing. For a fused weapon arm whose mesh is far longer than the arm the clips were keyed for
(Grimble's goo arm and bone crescent, ~1 m from shoulder to hook tip): a 20-40 degree swing that reads right on a thin
arm throws the crescent ~0.4 m out from his side.
Then, with --down=<bone>,<end>,<fraction>,<dx,dy,dz>, the bone swings that fraction of the way from where the clip points
the bone->end line (model space) to the direction given, at every key: on a clip that pitches the torso far forward (a
run) an arm hanging straight from the hips trails out behind him, so it is turned toward the ground instead.
Run: python3 tools/art1/glb_arm_hang.py <glb> <bone=fraction,...> <clip,clip,...> [--down=upper_arm.R,hook,0.6,0.15,-1,0.1]
Directions are glTF model space: +Y up, -Z the Hero's front, +X its right. Only the rotation output data changes (same
sizes), in place."""

import sys

import numpy as np

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from glb_add_clips import read, write  # noqa: E402
from glb_key_pose import Clip, qinv, qmul  # noqa: E402


def slerp(a, b, t):
    if np.dot(a, b) < 0.0:
        b = -b
    d = min(1.0, float(np.dot(a, b)))
    th = np.arccos(d)
    if th < 1e-6:
        return a
    return (np.sin((1 - t) * th) * a + np.sin(t * th) * b) / np.sin(th)


def main():
    glb, spec, clips = sys.argv[1], sys.argv[2], sys.argv[3].split(",")
    amount = {k: float(v) for k, v in (p.split("=") for p in spec.split(","))}
    j, b = read(glb)
    names = {n.get("name"): i for i, n in enumerate(j["nodes"])}
    want = {names[k]: a for k, a in amount.items()}
    users = {}
    for an in j["animations"]:
        for s in an["samplers"]:
            users[s["output"]] = users.get(s["output"], 0) + 1
    done = 0
    for an in j["animations"]:
        if an["name"] not in clips:
            continue
        for ch in an["channels"]:
            node = ch["target"]["node"]
            if node not in want or ch["target"]["path"] != "rotation":
                continue
            acc = an["samplers"][ch["sampler"]]["output"]
            if users[acc] != 1:
                sys.exit("shared rotation accessor %d in %s: not edited" % (acc, an["name"]))
            a = j["accessors"][acc]
            assert a["componentType"] == 5126 and a["type"] == "VEC4"
            v = j["bufferViews"][a["bufferView"]]
            off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
            q = np.frombuffer(b, np.float32, a["count"] * 4, off).reshape(-1, 4).astype(np.float64)
            rest = np.array(j["nodes"][node].get("rotation", [0, 0, 0, 1]), np.float64)
            out = np.array([slerp(k / np.linalg.norm(k), rest, want[node]) for k in q], np.float32)
            b[off:off + out.nbytes] = out.tobytes()
            if "min" in a:
                a["min"] = out.min(0).tolist()
                a["max"] = out.max(0).tolist()
            done += 1
    downs = [a[7:].split(",") for a in sys.argv[4:] if a.startswith("--down=")]
    for an in j["animations"]:
        if an["name"] not in clips:
            continue
        for bone, end, frac, *d in downs:
            c = Clip(j, b, an["name"])
            down(c, bone, end, float(frac), np.array([float(x) for x in d]))
    write(glb, j, b)
    print("glb_arm_hang: %d tracks eased toward rest, %d clips turned down" % (done, len(clips) if downs else 0))


def down(c, bone, end, frac, direction):
    """Swings bone so the bone->end line turns frac of the way to direction at every key (Clip.swing, constant weight)."""
    node = c.names[bone]
    if node not in c.rot:
        return
    _, voff, count = c.rot[node]
    d = direction / np.linalg.norm(direction)
    for k in range(count):
        pq, _ = c.world(c.parent[node], k)
        v = c.world(c.names[end], k)[1] - c.world(node, k)[1]
        v = v / np.linalg.norm(v)
        axis = np.cross(v, d)
        sin = np.linalg.norm(axis)
        if sin < 1e-6:
            continue
        half = np.arctan2(sin, float(v @ d)) * frac / 2.0
        delta = np.append(axis / sin * np.sin(half), np.cos(half))
        q = qmul(qmul(qmul(qinv(pq), delta), pq), c.get(c.rot, node, k, 4, "rotation"))
        c.b[voff + 16 * k : voff + 16 * k + 16] = (q / np.linalg.norm(q)).astype("<f4").tobytes()


if __name__ == "__main__":
    main()
