"""Copies named clips from one .glb into another, leaving everything already in the target byte for byte the same, so a clip set can go on any later build of the model
with no Blender (tracks match the target's nodes by name; both builds must share the rig: a translation track is moved by the difference of the two nodes' rest translations, so a source with
only the bones, their directions right and a face bone parked elsewhere, works). A clip of the same name in the target is replaced.
Run: python3 tools/art1/glb_add_clips.py <target.glb> <source.glb> <prefix-or-name>[,...] [out.glb]"""
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

    def accessor(i, shift=(0.0, 0.0, 0.0)):
        if (i, shift) in copied:
            return copied[(i, shift)]
        ac = dict(sj["accessors"][i])
        bv = dict(sj["bufferViews"][ac["bufferView"]])
        off0, ln = bv.get("byteOffset", 0), bv["byteLength"]
        tb.extend(b"\0" * (-len(tb) % 4))
        bv["byteOffset"] = len(tb)
        tb.extend(sb[off0:off0 + ln])
        if any(shift):
            v = list(struct.unpack_from("<%df" % (3 * ac["count"]), tb, bv["byteOffset"]))
            struct.pack_into("<%df" % len(v), tb, bv["byteOffset"], *[x + shift[k % 3] for k, x in enumerate(v)])
            ac.pop("min", None)
            ac.pop("max", None)
        bv["buffer"] = 0
        tj["bufferViews"].append(bv)
        ac["bufferView"] = len(tj["bufferViews"]) - 1
        tj["accessors"].append(ac)
        copied[(i, shift)] = len(tj["accessors"]) - 1
        return copied[(i, shift)]

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
            rest = [t - s for t, s in zip(tj["nodes"][names[nm]].get("translation", (0, 0, 0)), sj["nodes"][ch["target"]["node"]].get("translation", (0, 0, 0)))]
            shift = tuple(rest) if ch["target"]["path"] == "translation" and max(map(abs, rest)) > 1e-6 else (0.0, 0.0, 0.0)
            new["samplers"].append({"input": accessor(sm["input"]), "output": accessor(sm["output"], shift), "interpolation": sm.get("interpolation", "LINEAR")})
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
    sj, sb = read(source)
    done = add(tj, tb, sj, sb, lambda n: any(n == k or n.startswith(k) for k in keys))
    write(out, tj, tb)
    print("added", len(done), done)
