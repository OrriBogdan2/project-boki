"""Ports a body's rig-side work from one build of a glb into another build of the same model (same mesh, skin, nodes
and clip/channel layout), leaving the rest of DST as it is. Made 11-25 for Meeko: main took PR #764's sun/cloud while
ext/meeko-body-1124 carried rounds 2-10 of body keys and weights on the older companions; this puts that body work
on main's file instead of re-running ten rounds of tools.

  python3 tools/art1/glb_port_body.py OUT.glb DST.glb SRC.glb [--prims=0,6] [--attrs=JOINTS_0,WEIGHTS_0] [--anims] [--images=4]

--prims/--attrs: those vertex attributes of those primitives of mesh 0 are copied (vertex counts must match).
--anims: every animation channel's sampler input+output is copied (channels must target the same node/path in order).
--images: those image indices' bytes are copied (same index in both files).
Then run tools/art1/glb_compact.py OUT OUT to drop the replaced bytes."""

import json
import struct
import sys


def load(p):
    b = open(p, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    js = json.loads(b[20 : 20 + n])
    o = 20 + n
    m = struct.unpack("<I", b[o : o + 4])[0]
    return js, bytearray(b[o + 8 : o + 8 + m])


def view_of(js, bn, vi):
    v = js["bufferViews"][vi]
    return bytes(bn[v.get("byteOffset", 0) : v.get("byteOffset", 0) + v["byteLength"]])


def main():
    out, dst, src = sys.argv[1:4]
    opt = dict(a[2:].split("=", 1) if "=" in a else (a[2:], "1") for a in sys.argv[4:])
    D, Db = load(dst)
    S, Sb = load(src)

    def append(raw, like):
        while len(Db) % 4:
            Db.append(0)
        v = dict(like)
        v["byteOffset"] = len(Db)
        v["byteLength"] = len(raw)
        v.pop("buffer", None)
        v["buffer"] = 0
        Db.extend(raw)
        D["bufferViews"].append(v)
        return len(D["bufferViews"]) - 1

    def port_acc(di, si):
        sa = S["accessors"][si]
        sv = S["bufferViews"][sa["bufferView"]]
        raw = view_of(S, Sb, sa["bufferView"])
        na = dict(sa)
        na["bufferView"] = append(raw, sv)
        D["accessors"][di] = na

    n = 0
    if "prims" in opt:
        attrs = opt.get("attrs", "JOINTS_0,WEIGHTS_0").split(",")
        for pi in map(int, opt["prims"].split(",")):
            dp, sp = D["meshes"][0]["primitives"][pi], S["meshes"][0]["primitives"][pi]
            for k in attrs:
                assert D["accessors"][dp["attributes"][k]]["count"] == S["accessors"][sp["attributes"][k]]["count"], (
                    pi,
                    k,
                )
                port_acc(dp["attributes"][k], sp["attributes"][k])
                n += 1
    if "anims" in opt:
        for da, sa in zip(D["animations"], S["animations"]):
            assert da["name"] == sa["name"] and len(da["channels"]) == len(sa["channels"])
            for dc, sc in zip(da["channels"], sa["channels"]):
                assert dc["target"] == sc["target"], (da["name"], dc["target"])
                ds, ss = da["samplers"][dc["sampler"]], sa["samplers"][sc["sampler"]]
                # the input accessor may be shared by many samplers: give every ported sampler its own copy
                for key in ("input", "output"):
                    D["accessors"].append(None)
                    port_acc(len(D["accessors"]) - 1, ss[key])
                    ds[key] = len(D["accessors"]) - 1
                ds["interpolation"] = ss.get("interpolation", "LINEAR")
                n += 1
    if "images" in opt:
        for ii in map(int, opt["images"].split(",")):
            si = S["images"][ii]
            D["images"][ii]["bufferView"] = append(view_of(S, Sb, si["bufferView"]), S["bufferViews"][si["bufferView"]])
            D["images"][ii]["mimeType"] = si["mimeType"]
            n += 1
    D["buffers"][0]["byteLength"] = len(Db)
    js = json.dumps(D, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    Db.extend(b"\0" * (-len(Db) % 4))
    with open(out, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(Db)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(Db), 0x004E4942) + Db)
    print("ported", n, "items ->", out)


if __name__ == "__main__":
    main()
