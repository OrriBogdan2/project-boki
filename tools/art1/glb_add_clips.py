"""Copies named clips from one .glb into another, leaving everything already in the target byte for byte the same, so a clip set can go on any later build of the model
with no Blender (tracks match the target's nodes by name; both builds must share the rig). A clip of the same name in the target is replaced.
Run: python3 tools/art1/glb_add_clips.py <target.glb> <source.glb> <prefix-or-name>[,...] [out.glb]
Drop: python3 tools/art1/glb_add_clips.py --drop <target.glb> <name>[,...] [out.glb] removes those clips (exact names) and
the data only they used; meshes, skins, images and the other clips keep their bytes."""
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


def compact(j, bin_):
    """Keeps only the accessors and buffer views something still points at, so a dropped clip leaves no bytes behind."""
    used = set()
    for m in j.get("meshes", []):
        for p in m["primitives"]:
            used.update(p.get("attributes", {}).values())
            if "indices" in p:
                used.add(p["indices"])
            for t in p.get("targets", []):
                used.update(t.values())
    for sk in j.get("skins", []):
        if "inverseBindMatrices" in sk:
            used.add(sk["inverseBindMatrices"])
    for a in j.get("animations", []):
        for sm in a["samplers"]:
            used.update((sm["input"], sm["output"]))
    if any("sparse" in ac for ac in j["accessors"]):
        raise SystemExit("sparse accessors: not handled")
    acc = sorted(used)
    amap = {o: n for n, o in enumerate(acc)}
    views = sorted({j["accessors"][i]["bufferView"] for i in acc if "bufferView" in j["accessors"][i]} |
                   {im["bufferView"] for im in j.get("images", []) if "bufferView" in im})
    vmap = {o: n for n, o in enumerate(views)}
    nb, nviews = bytearray(), []
    for o in views:
        bv = dict(j["bufferViews"][o])
        off0, ln = bv.get("byteOffset", 0), bv["byteLength"]
        nb.extend(b"\0" * (-len(nb) % 16))
        bv["byteOffset"] = len(nb)
        nb.extend(bin_[off0:off0 + ln])
        nviews.append(bv)
    naccs = []
    for o in acc:
        ac = dict(j["accessors"][o])
        if "bufferView" in ac:
            ac["bufferView"] = vmap[ac["bufferView"]]
        naccs.append(ac)
    for m in j.get("meshes", []):
        for p in m["primitives"]:
            p["attributes"] = {k: amap[v] for k, v in p.get("attributes", {}).items()}
            if "indices" in p:
                p["indices"] = amap[p["indices"]]
            if "targets" in p:
                p["targets"] = [{k: amap[v] for k, v in t.items()} for t in p["targets"]]
    for sk in j.get("skins", []):
        if "inverseBindMatrices" in sk:
            sk["inverseBindMatrices"] = amap[sk["inverseBindMatrices"]]
    for a in j.get("animations", []):
        for sm in a["samplers"]:
            sm["input"], sm["output"] = amap[sm["input"]], amap[sm["output"]]
    for im in j.get("images", []):
        if "bufferView" in im:
            im["bufferView"] = vmap[im["bufferView"]]
    j["accessors"], j["bufferViews"] = naccs, nviews
    j["buffers"][0]["byteLength"] = len(nb) + (-len(nb) % 4)
    return nb


if __name__ == "__main__" and sys.argv[1:2] == ["--drop"]:
    target, keys = sys.argv[2:4]
    out = sys.argv[4] if len(sys.argv) > 4 else target
    keys = set(keys.split(","))
    tj, tb = read(target)
    have = {a["name"] for a in tj.get("animations", [])}
    if keys - have:
        raise SystemExit("no clip %s in %s" % (sorted(keys - have), target))
    tj["animations"] = [a for a in tj["animations"] if a["name"] not in keys]
    tb = compact(tj, tb)
    write(out, tj, tb)
    print("dropped", sorted(keys), "clips left", len(tj["animations"]))
elif __name__ == "__main__":
    target, source, keys = sys.argv[1:4]
    out = sys.argv[4] if len(sys.argv) > 4 else target
    keys = keys.split(",")
    tj, tb = read(target)
    sj, sb = read(source)
    done = add(tj, tb, sj, sb, lambda n: any(n == k or n.startswith(k) for k in keys))
    write(out, tj, tb)
    print("added", len(done), done)
