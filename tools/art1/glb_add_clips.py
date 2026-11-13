"""Copies named clips from one .glb into another, leaving everything already in the target byte for byte the same, so a clip set can go on any later build of the model
with no Blender (tracks match the target's nodes by name; both builds must share the rig). A clip of the same name in the target is replaced.
Run: python3 tools/art1/glb_add_clips.py <target.glb> <source.glb> <prefix-or-name>[,...] [out.glb] [--hold-moved-rest]
--hold-moved-rest: a node whose rest (translation/rotation) differs between the two builds (a spring bone the new model moved)
gets its target rest held for the whole clip instead of the source's keys; the held names are printed. Use it only when the
moved nodes are ones the clips hold still anyway (spring chains: the runtime sim moves them)."""
import json
import math
import struct
import sys

REST = {"translation": [0.0, 0.0, 0.0], "rotation": [0.0, 0.0, 0.0, 1.0], "scale": [1.0, 1.0, 1.0]}


def rest_moved(a, b, tol=0.002):
    ta, tb = a.get("translation", REST["translation"]), b.get("translation", REST["translation"])
    qa, qb = a.get("rotation", REST["rotation"]), b.get("rotation", REST["rotation"])
    dot = min(1.0, abs(sum(x * y for x, y in zip(qa, qb))))
    return max(abs(x - y) for x, y in zip(ta, tb)) > tol or 2 * math.degrees(math.acos(dot)) > 0.5


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


def add(tj, tb, sj, sb, wanted, hold=False, held=None):
    names = {n.get("name"): i for i, n in enumerate(tj["nodes"])}
    snames = {n.get("name"): n for n in sj["nodes"]}

    def const(vals, typ, minmax=False):
        tb.extend(b"\0" * (-len(tb) % 4))
        tj["bufferViews"].append({"buffer": 0, "byteOffset": len(tb), "byteLength": 4 * len(vals)})
        tb.extend(struct.pack("<%df" % len(vals), *vals))
        acc = {"bufferView": len(tj["bufferViews"]) - 1, "componentType": 5126, "count": 2, "type": typ}
        if minmax:
            acc["min"], acc["max"] = [min(vals)], [max(vals)]
        tj["accessors"].append(acc)
        return len(tj["accessors"]) - 1
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
            if hold and rest_moved(snames[nm], tj["nodes"][names[nm]]):
                path = ch["target"]["path"]
                end = max(sj["accessors"][s["input"]]["max"][0] for s in a["samplers"])
                v = tj["nodes"][names[nm]].get(path, REST[path])
                new["samplers"].append({"input": const([0.0, end], "SCALAR", True), "output": const(list(v) * 2, "VEC4" if path == "rotation" else "VEC3"), "interpolation": "LINEAR"})
                new["channels"].append({"sampler": len(new["samplers"]) - 1, "target": {"node": names[nm], "path": path}})
                if held is not None:
                    held.add(nm)
                continue
            new["samplers"].append({"input": accessor(sm["input"]), "output": accessor(sm["output"]), "interpolation": sm.get("interpolation", "LINEAR")})
            new["channels"].append({"sampler": len(new["samplers"]) - 1, "target": {"node": names[nm], "path": ch["target"]["path"]}})
        tj["animations"].append(new)
        done.append(a["name"])
    tj["buffers"][0]["byteLength"] = len(tb) + (-len(tb) % 4)
    return done


if __name__ == "__main__":
    hold = "--hold-moved-rest" in sys.argv
    args = [x for x in sys.argv[1:] if x != "--hold-moved-rest"]
    target, source, keys = args[:3]
    out = args[3] if len(args) > 3 else target
    keys = keys.split(",")
    tj, tb = read(target)
    sj, sb = read(source)
    held = set()
    done = add(tj, tb, sj, sb, lambda n: any(n == k or n.startswith(k) for k in keys), hold, held)
    write(out, tj, tb)
    print("added", len(done), done)
    if hold:
        print("held at target rest:", sorted(held))
