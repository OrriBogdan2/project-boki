"""Rebuilds a torn lower limb of a shipped Hero .glb from its clean mirror twin, in place (one material's primitive).
Grimble's right shin and foot stood in the floor puddle: the Meshy faces under it went with the puddle, so his right
foot is a fan of shards and holes that tears in every clip. His rig is mirror-symmetric (thigh/shin/foot .L/.R at
x = +/-0.163 with the same rest rotations), so the left foot mirrored on x and moved onto the .R bones deforms right.
Drops the triangles of the --to side's limb below --below (m, rest height; a triangle goes when its vertices' --to
weight averages over 0.5), then appends the --from side's triangles under --below + --overlap, mirrored (x negated,
winding reversed, normals mirrored, same UVs and colours, joints renamed .L <-> .R). Every other byte stays: the
buffer is rebuilt with only this primitive's attributes and indices replaced.
Run: python3 tools/art1/glb_mirror_limb.py IN.glb OUT.glb [--mat skin-v95] [--from L] [--to R] [--below 0.30]
     [--overlap 0.02] [--bones thigh,shin,foot]"""

import argparse
import json
import struct

import numpy as np

CT = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def load(path):
    b = open(path, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20 : 20 + n])
    off = 20 + n
    bl = struct.unpack("<I", b[off : off + 4])[0]
    return j, b[off + 8 : off + 8 + bl]


def view(j, binb, bvi):
    bv = j["bufferViews"][bvi]
    o = bv.get("byteOffset", 0)
    return binb[o : o + bv["byteLength"]]


def read(j, binb, ai):
    ac = j["accessors"][ai]
    bv = j["bufferViews"][ac["bufferView"]]
    dt, n = np.dtype(CT[ac["componentType"]]), NC[ac["type"]]
    assert not bv.get("byteStride") or bv["byteStride"] == dt.itemsize * n
    o = bv.get("byteOffset", 0) + ac.get("byteOffset", 0)
    return np.frombuffer(binb, dtype=dt, count=ac["count"] * n, offset=o).reshape(ac["count"], n).copy()


def save(path, j, binb, repl):
    """repl: {accessor index: new array}. Rebuilds the buffer view by view (4-byte aligned)."""
    acc_of = {j["accessors"][a]["bufferView"]: a for a in repl}
    out = bytearray()
    for i, bv in enumerate(j["bufferViews"]):
        data = view(j, binb, i)
        if i in acc_of:
            a = acc_of[i]
            ac = j["accessors"][a]
            arr = repl[a].astype(CT[ac["componentType"]])
            assert ac.get("byteOffset", 0) == 0
            data = arr.tobytes()
            ac["count"] = int(arr.shape[0] if ac["type"] != "SCALAR" else arr.size)
            if "min" in ac:
                r = arr.reshape(ac["count"], -1)
                ac["min"] = [float(x) for x in r.min(0)]
                ac["max"] = [float(x) for x in r.max(0)]
        while len(out) % 4:
            out.append(0)
        bv["byteOffset"] = len(out)
        bv["byteLength"] = len(data)
        out += data
    while len(out) % 4:
        out.append(0)
    j["buffers"][0]["byteLength"] = len(out)
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    total = 12 + 8 + len(js) + 8 + len(out)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(out), 0x004E4942) + bytes(out))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("inp")
    ap.add_argument("out")
    ap.add_argument("--mat", default="skin-v95")
    ap.add_argument("--from", dest="src", default="L")
    ap.add_argument("--to", dest="dst", default="R")
    ap.add_argument("--below", type=float, default=0.30)
    ap.add_argument("--overlap", type=float, default=0.02)
    ap.add_argument("--bones", default="thigh,shin,foot")
    a = ap.parse_args()
    j, binb = load(a.inp)
    names = [j["nodes"][n]["name"] for n in j["skins"][0]["joints"]]
    prim = [p for m in j["meshes"] for p in m["primitives"] if j["materials"][p["material"]]["name"] == a.mat][0]
    at = prim["attributes"]
    arr = {k: read(j, binb, v) for k, v in at.items()}
    idx = read(j, binb, prim["indices"]).reshape(-1, 3).astype(np.int64)
    pos, J, W = arr["POSITION"].astype(np.float64), arr["JOINTS_0"].astype(np.int64), arr["WEIGHTS_0"]
    bones = a.bones.split(",")
    src = [names.index(f"{b}.{a.src}") for b in bones]
    dst = [names.index(f"{b}.{a.dst}") for b in bones]
    ws = (W * np.isin(J, src)).sum(1)
    wd = (W * np.isin(J, dst)).sum(1)
    cy = pos[idx].mean(1)[:, 1]
    drop = (cy < a.below) & (wd[idx].mean(1) > 0.5)
    take = (cy < a.below + a.overlap) & (ws[idx] > 0.5).all(1)
    print(f"drop {drop.sum()} tris of the {a.dst} limb under {a.below} m; mirror {take.sum()} tris of the {a.src} limb")
    used = np.unique(idx[take])
    remap = {int(v): len(pos) + i for i, v in enumerate(used)}
    jmap = np.arange(len(names))
    for s, d in zip(src, dst):
        jmap[s] = d
        jmap[d] = s
    for k in arr:
        new = arr[k][used].copy()
        if k in ("POSITION", "NORMAL"):
            new[:, 0] = -new[:, 0]
        if k == "TANGENT":
            new[:, 0] = -new[:, 0]
            new[:, 3] = -new[:, 3]
        if k == "JOINTS_0":
            new = jmap[new.astype(np.int64)].astype(arr[k].dtype)
        arr[k] = np.concatenate([arr[k], new])
    newtri = np.vectorize(remap.get)(idx[take])[:, ::-1]
    idx2 = np.concatenate([idx[~drop], newtri])
    assert len(arr["POSITION"]) < 65536 or j["accessors"][prim["indices"]]["componentType"] == 5125
    repl = {at[k]: arr[k] for k in arr}
    repl[prim["indices"]] = idx2.reshape(-1)
    save(a.out, j, binb, repl)
    print(f"verts {len(pos)} -> {len(arr['POSITION'])}, tris {len(idx)} -> {len(idx2)}")


if __name__ == "__main__":
    main()
