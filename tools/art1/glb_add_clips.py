"""Copies named clips from one .glb into another, leaving everything already in the target byte for byte the same, so a clip set can go on any later build of the model
with no Blender (tracks match the target's nodes by name; both builds must share the rig). A clip of the same name in the target is replaced.
The source may also be a keys .json (tools/revive_bake.gd: {"name", "fps", "frames", "bones": {bone: {"rotation": [xyzw..],
"translation": [xyz..]}}}, one key per frame); its bone names match the target's nodes with "_" read as ".".
Run: python3 tools/art1/glb_add_clips.py <target.glb> <source.glb|keys.json> <prefix-or-name>[,...] [out.glb]"""
import json
import struct
import sys


def read(path):
    b = open(path, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + n])
    at = 20 + n
    m = struct.unpack("<I", b[at:at + 4])[0]
    return j, bytearray(b[at + 8:at + 8 + m])


def write(path, j, bin_):
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    bin_ += b"\0" * (-len(bin_) % 4)
    j_len = len(js)
    total = 12 + 8 + j_len + 8 + len(bin_)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", j_len, b"JSON"))
        f.write(js)
        f.write(struct.pack("<I4s", len(bin_), b"BIN\0"))
        f.write(bin_)


def from_keys(path, node_names):
    """A keys .json as a one-clip glTF (json, bin) for add(): nodes named as the target's."""
    k = json.load(open(path))
    norm = {n.replace("_", "."): n for n in node_names if n}
    sj = {"nodes": [], "accessors": [], "bufferViews": [], "animations": [{"name": k["name"], "channels": [], "samplers": []}]}
    sb = bytearray()

    def accessor(vals, kind):
        flat = [float(x) for v in vals for x in (v if isinstance(v, list) else [v])]
        sj["bufferViews"].append({"buffer": 0, "byteOffset": len(sb), "byteLength": 4 * len(flat)})
        sb.extend(struct.pack("<%df" % len(flat), *flat))
        ac = {"bufferView": len(sj["bufferViews"]) - 1, "componentType": 5126, "count": len(vals), "type": kind}
        if kind == "SCALAR":
            ac["min"], ac["max"] = [min(flat)], [max(flat)]
        sj["accessors"].append(ac)
        return len(sj["accessors"]) - 1

    times = accessor([i / k["fps"] for i in range(k["frames"])], "SCALAR")
    anim = sj["animations"][0]
    for bone, paths in k["bones"].items():
        sj["nodes"].append({"name": norm.get(bone.replace("_", "."), bone)})
        for path, vals in paths.items():
            anim["samplers"].append({"input": times, "output": accessor(vals, "VEC4" if path == "rotation" else "VEC3")})
            anim["channels"].append({"sampler": len(anim["samplers"]) - 1, "target": {"node": len(sj["nodes"]) - 1, "path": path}})
    return sj, sb


def add(tj, tb, sj, sb, wanted):
    names = {n.get("name"): i for i, n in enumerate(tj["nodes"])}
    tj["animations"] = [a for a in tj.get("animations", []) if not wanted(a["name"])]
    copied = {}

    def accessor(i):
        if i in copied:
            return copied[i]
        ac = dict(sj["accessors"][i])
        bv = dict(sj["bufferViews"][ac["bufferView"]])
        off0, ln = bv.get("byteOffset", 0), bv["byteLength"]
        tb.extend(b"\0" * (-len(tb) % 4))
        bv["byteOffset"] = len(tb)
        tb.extend(sb[off0:off0 + ln])
        bv["buffer"] = 0
        tj["bufferViews"].append(bv)
        ac["bufferView"] = len(tj["bufferViews"]) - 1
        tj["accessors"].append(ac)
        copied[i] = len(tj["accessors"]) - 1
        return copied[i]

    done = []
    for a in sj["animations"]:
        if not wanted(a["name"]):
            continue
        new = {"name": a["name"], "channels": [], "samplers": []}
        for ch in a["channels"]:
            nm = sj["nodes"][ch["target"]["node"]].get("name")
            if nm not in names:
                raise SystemExit("%s: no node %s in the target" % (a["name"], nm))
            sm = a["samplers"][ch["sampler"]]
            new["samplers"].append({"input": accessor(sm["input"]), "output": accessor(sm["output"]), "interpolation": sm.get("interpolation", "LINEAR")})
            new["channels"].append({"sampler": len(new["samplers"]) - 1, "target": {"node": names[nm], "path": ch["target"]["path"]}})
        tj["animations"].append(new)
        done.append(a["name"])
    tj["buffers"][0]["byteLength"] = len(tb) + (-len(tb) % 4)
    return done


if __name__ == "__main__":
    target, source, keys = sys.argv[1:4]
    out = sys.argv[4] if len(sys.argv) > 4 else target
    keys = keys.split(",")
    tj, tb = read(target)
    sj, sb = from_keys(source, [n.get("name") for n in tj["nodes"]]) if source.endswith(".json") else read(source)
    done = add(tj, tb, sj, sb, lambda n: any(n == k or n.startswith(k) for k in keys))
    write(out, tj, tb)
    print("added", len(done), done)
