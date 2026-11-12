"""Eases the start of one clip of a .glb toward another clip's pose, with no Blender, so the clip begins nearer the pose
the game hands it over from (--clip-check's pop rows). On the named bones the first keys take `share` of the other
clip's local rotation at `at`, easing back to the clip's own keys by `t1` (smoothstep); every other key stays as it is.
The new keys are appended; the old data stays in the file unused.
Run: python3 tools/art1/glb_blend_start.py <glb> <clip> <from-clip> <at> <bone>[,<bone>...] <share> <t1> [out.glb]
  e.g. kael.glb riposte guard 0.2 upper_arm.R,forearm.R,hand.R 1.0 0.034  (the riposte starts in the guard's arm)"""
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from glb_add_clips import read, write
from glb_retime import append, floats, slerp


def rotation(j, b, anim, node):
    """(times, quaternions, sampler) of a clip's rotation track on one node."""
    for ch in anim["channels"]:
        if ch["target"]["node"] == node and ch["target"]["path"] == "rotation":
            sm = anim["samplers"][ch["sampler"]]
            n = j["accessors"][sm["input"]]["count"]
            vs = floats(j, b, sm["output"], 4 * n)
            return floats(j, b, sm["input"], n), [list(vs[4 * k:4 * k + 4]) for k in range(n)], sm
    raise SystemExit("no rotation track on node %d" % node)


def sample(times, quats, t):
    k = max(i for i in range(len(times)) if times[i] <= t + 1e-9) if t > times[0] else 0
    if k + 1 >= len(times):
        return quats[k]
    return slerp(quats[k], quats[k + 1], (t - times[k]) / (times[k + 1] - times[k]))


def blend_start(j, b, clip, src, at, bones, share, t1):
    anims = {a["name"]: a for a in j["animations"]}
    names = {n.get("name"): i for i, n in enumerate(j["nodes"])}
    for bone in bones:
        ts, qs, _ = rotation(j, b, anims[src], names[bone])
        goal = sample(ts, qs, at)
        times, quats, sm = rotation(j, b, anims[clip], names[bone])
        out = []
        for t, q in zip(times, quats):
            u = min(max(t / t1, 0.0), 1.0)
            out.extend(slerp(q, goal, share * (1.0 - u * u * (3.0 - 2.0 * u))))
        sm["output"] = append(j, b, out, "VEC4")
    j["buffers"][0]["byteLength"] = len(b) + (-len(b) % 4)


if __name__ == "__main__":
    path, clip, src, at, bones, share, t1 = sys.argv[1:8]
    glb, binary = read(path)
    blend_start(glb, binary, clip, src, float(at), bones.split(","), float(share), float(t1))
    write(sys.argv[8] if len(sys.argv) > 8 else path, glb, binary)
    print("blended", clip, "from", src, "@", at, "on", bones)
