"""Writes a clips-only .glb: the rig of one build (its nodes and skin; no mesh, material or image) carrying clips
copied from another build under new names, so a Hero gets new clips without its model .glb being re-exported.
The game adds such a file's clips to the Hero's library (warden_anim "clip_files", scripts/heroes/warden_clip_file.gd).
Run: python3 -I tools/art1/glb_clips_only.py <rig.glb> <source.glb> <clip>=<new name>[,...] <out.glb>
Both builds must share the rig (glb_add_clips matches tracks by node name and moves translation tracks to the
rig's rest)."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb_add_clips  # noqa: E402


def rig_only(j, bin_):
    """The rig of a build: every node (so indices hold) without its mesh, and the skin with its bind matrices."""
    out = {"asset": j["asset"], "scene": j.get("scene", 0), "scenes": j["scenes"], "buffers": [{"byteLength": 0}]}
    out["nodes"] = [{k: v for k, v in n.items() if k not in ("mesh", "skin")} for n in j["nodes"]]
    out["bufferViews"], out["accessors"], out["skins"] = [], [], []
    out_bin = bytearray()
    for skin in j.get("skins", []):
        acc = dict(j["accessors"][skin["inverseBindMatrices"]])
        view = dict(j["bufferViews"][acc["bufferView"]])
        start = view.get("byteOffset", 0)
        view.update({"buffer": 0, "byteOffset": len(out_bin)})
        out_bin.extend(bin_[start : start + view["byteLength"]])
        out_bin.extend(b"\0" * (-len(out_bin) % 4))
        out["bufferViews"].append(view)
        acc["bufferView"] = len(out["bufferViews"]) - 1
        out["accessors"].append(acc)
        out["skins"].append(dict(skin, inverseBindMatrices=len(out["accessors"]) - 1))
    return out, out_bin


if __name__ == "__main__":
    rig, source, pairs, dest = sys.argv[1:5]
    names = dict(p.split("=") for p in pairs.split(","))
    rig_json, rig_bin = rig_only(*glb_add_clips.read(rig))
    src_json, src_bin = glb_add_clips.read(source)
    done = glb_add_clips.add(rig_json, rig_bin, src_json, src_bin, lambda n: n in names)
    for clip in rig_json["animations"]:
        clip["name"] = names[clip["name"]]
    glb_add_clips.write(dest, rig_json, rig_bin)
    print("wrote", dest, [names[n] for n in done], os.path.getsize(dest), "bytes")
