"""Copies named clips from one .glb into another, leaving everything else in the target unchanged (the replaced clips' data is dropped), so a clip set can go on any later build of the model
with no Blender (tracks match the target's nodes by name; both builds must share the rig). A clip of the same name in the target is replaced.
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


def accessor_refs(j):
    """Every place that names an accessor: (dict, key) pairs."""
    out = []
    for m in j.get("meshes", []):
        for pr in m["primitives"]:
            out += [(pr["attributes"], k) for k in pr["attributes"]] + ([(pr, "indices")] if "indices" in pr else [])
            out += [(t, k) for t in pr.get("targets", []) for k in t]
    out += [(s, "inverseBindMatrices") for s in j.get("skins", []) if "inverseBindMatrices" in s]
    out += [(s, k) for a in j.get("animations", []) for s in a["samplers"] for k in ("input", "output")]
    return out


def prune(j, bin_):
    """Drops the accessors and buffer views nothing names any more (a replaced clip's), packing the bytes that stay."""
    refs = accessor_refs(j)
    keep_ac = sorted({d[k] for d, k in refs})
    ac_at = {old: new for new, old in enumerate(keep_ac)}
    for d, k in refs:
        d[k] = ac_at[d[k]]
    j["accessors"] = [j["accessors"][i] for i in keep_ac]
    users = j["accessors"] + [im for im in j.get("images", []) if "bufferView" in im]
    keep_bv = sorted({u["bufferView"] for u in users})
    bv_at = {old: new for new, old in enumerate(keep_bv)}
    for u in users:
        u["bufferView"] = bv_at[u["bufferView"]]
    out = bytearray()
    views = []
    for i in keep_bv:
        bv = dict(j["bufferViews"][i])
        off0 = bv.get("byteOffset", 0)
        out.extend(b"\0" * (-len(out) % 4))
        bv["byteOffset"] = len(out)
        out.extend(bin_[off0:off0 + bv["byteLength"]])
        views.append(bv)
    j["bufferViews"] = views
    j["buffers"][0]["byteLength"] = len(out) + (-len(out) % 4)
    return out


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
    sj, sb = read(source)
    done = add(tj, tb, sj, sb, lambda n: any(n == k or n.startswith(k) for k in keys))
    write(out, tj, prune(tj, tb))
    print("added", len(done), done)
