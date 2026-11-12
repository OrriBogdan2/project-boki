"""Copies named clips from one .glb into another, leaving everything already in the target byte for byte the same, so a clip set can go on any later build of the model
with no Blender (tracks match the target's nodes by name; both builds must share the rig). A clip of the same name in the target is replaced.
Run: python3 tools/art1/glb_add_clips.py <target.glb> <source.glb> <prefix-or-name>[,...] [out.glb]
Stretch: python3 tools/art1/glb_add_clips.py --stretch <target.glb> <prefix-or-name>[,...] <seconds> [out.glb] re-times every
matching clip to one length (the walk and run rings of a Hunter share a length and a strike key, so crossfading them
never blends arms half a stride apart: docs/art/LOCO_DIR.md); keys keep their shape, only their times scale."""
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


def _copy_accessor(j, b, i):
    """A new accessor over a copy of accessor i's bytes appended to the binary; returns its index."""
    ac = dict(j["accessors"][i])
    bv = dict(j["bufferViews"][ac["bufferView"]])
    at, ln = bv.get("byteOffset", 0) + ac.get("byteOffset", 0), ac["count"] * 4
    b.extend(b"\0" * (-len(b) % 4))
    bv["byteOffset"], bv["byteLength"] = len(b), ln
    ac.pop("byteOffset", None)
    b.extend(b[at:at + ln])
    j["bufferViews"].append(bv)
    ac["bufferView"] = len(j["bufferViews"]) - 1
    j["accessors"].append(ac)
    j["buffers"][0]["byteLength"] = len(b) + (-len(b) % 4)
    return len(j["accessors"]) - 1


def stretch(j, b, wanted, seconds):
    """Scales the key times of the wanted clips so each ends at `seconds`; returns their names."""
    factor = {}
    done = []
    for a in j["animations"]:
        if not wanted(a["name"]):
            continue
        end = max(j["accessors"][s["input"]]["max"][0] for s in a["samplers"])
        for s in a["samplers"]:
            if factor.setdefault(s["input"], seconds / end) != seconds / end:
                raise SystemExit("%s shares key times with a clip of another length" % a["name"])
        done.append(a["name"])
    for a in j["animations"]:     # (key times a stretched clip shares with another clip are copied, not scaled under it)
        if not wanted(a["name"]) and any(s["input"] in factor for s in a["samplers"]):
            for s in (s for s in a["samplers"] if s["input"] in factor):
                s["input"] = _copy_accessor(j, b, s["input"])
    for i, k in factor.items():
        ac = j["accessors"][i]
        bv = j["bufferViews"][ac["bufferView"]]
        at = bv.get("byteOffset", 0) + ac.get("byteOffset", 0)
        times = [t * k for t in struct.unpack_from("<%df" % ac["count"], b, at)]
        struct.pack_into("<%df" % ac["count"], b, at, *times)
        ac["min"], ac["max"] = [min(times)], [max(times)]
    return done


if __name__ == "__main__":
    if sys.argv[1] == "--stretch":
        target, keys, seconds = sys.argv[2:5]
        out = sys.argv[5] if len(sys.argv) > 5 else target
        tj, tb = read(target)
        done = stretch(tj, tb, lambda n: any(n == k or n.startswith(k) for k in keys.split(",")), float(seconds))
        write(out, tj, tb)
        print("stretched", len(done), done)
        raise SystemExit
    target, source, keys = sys.argv[1:4]
    out = sys.argv[4] if len(sys.argv) > 4 else target
    keys = keys.split(",")
    tj, tb = read(target)
    sj, sb = read(source)
    done = add(tj, tb, sj, sb, lambda n: any(n == k or n.startswith(k) for k in keys))
    write(out, tj, tb)
    print("added", len(done), done)
