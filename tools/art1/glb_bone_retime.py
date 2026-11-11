"""Re-times some bones of one clip of a .glb with no Blender: like glb_retime.py, but only the tracks of the named
bones are warped, so an arm's move can spread over more frames while the body keeps every beat. The old key data stays
in the file unused; the new keys are appended.
Run: python3 tools/art1/glb_bone_retime.py <glb> <clip> <bone>[,<bone>...] <new:old>[,<new:old>...] [out.glb]
  e.g. vault_r upper_arm.R,forearm.R,hand.R 0.15:0.067,0.27:0.1,0.28:0.264
  (the pose the arm had at 0.067 s now arrives at 0.15 s; the end maps to itself)"""
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from glb_add_clips import read, write
from glb_retime import retime


def bone_retime(j, b, clip, bones, anchors):
    """retime() on a view of the clip holding only the named bones' tracks (the same sampler objects, so the clip changes)."""
    anim = next(a for a in j["animations"] if a["name"] == clip)
    names = {i: n.get("name") for i, n in enumerate(j["nodes"])}
    keep = [c for c in anim["channels"] if names[c["target"]["node"]] in bones]
    missing = set(bones) - {names[c["target"]["node"]] for c in keep}
    if missing:
        sys.exit("no tracks in %s for %s" % (clip, ", ".join(sorted(missing))))
    used = [c["sampler"] for c in anim["channels"]]
    if any(used.count(c["sampler"]) > 1 for c in keep):
        sys.exit("a sampler of %s is shared with another track" % clip)
    part = {"name": clip, "channels": keep, "samplers": [anim["samplers"][c["sampler"]] for c in keep]}
    j["animations"].insert(0, part)   # retime() takes the first clip of that name; its samplers are the clip's own
    retime(j, b, clip, anchors)
    j["animations"].remove(part)


if __name__ == "__main__":
    path, clip, bones, spec = sys.argv[1:5]
    glb, binary = read(path)
    first = next(a for a in glb["animations"] if a["name"] == clip)["samplers"][0]["input"]
    end = glb["accessors"][first]["max"][0]
    anchors = [(0.0, 0.0)] + [tuple(float(x) for x in p.split(":")) for p in spec.split(",")] + [(end, end)]
    bone_retime(glb, binary, clip, bones.split(","), anchors)
    write(sys.argv[5] if len(sys.argv) > 5 else path, glb, binary)
    print("retimed", bones, "in", clip, "length", end)
