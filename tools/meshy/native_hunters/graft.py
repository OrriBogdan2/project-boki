"""Puts the decimated geometry (decimate.py's output) back into the rigged .glb: its primitives are matched by
material name, the skin joints by bone name. Node tree, skin, materials, textures and clips stay IN.glb's; the old
vertex data is dropped.

  python3 graft.py OUT.glb IN.glb DECIMATED.glb
"""

import sys

import numpy as np

sys.path.insert(0, __file__.rsplit("/", 2)[0])
import native_pack as npk

DTYPE = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}


def read(js, bin_, ai):
    a = js["accessors"][ai]
    n = npk.COMP[a["type"]]
    raw = npk.view_bytes(js, bin_, a["bufferView"])
    arr = np.frombuffer(raw, DTYPE[a["componentType"]], a["count"] * n, a.get("byteOffset", 0)).reshape(a["count"], n)
    return arr.astype(np.float32) if a.get("normalized") else arr.copy()


def joint_names(js):
    return [js["nodes"][j]["name"] for j in js["skins"][0]["joints"]]


def main(out_path, in_path, dec_path):
    js, bin_ = npk.load(in_path)
    djs, dbin = npk.load(dec_path)
    names = joint_names(js)
    remap = np.array([names.index(n) for n in joint_names(djs)], np.uint16)
    dec = {djs["materials"][p["material"]]["name"]: p for m in djs["meshes"] for p in m["primitives"]}
    new = []  # (primitive, {attribute: array}, indices)
    for m in js["meshes"]:
        for p in m["primitives"]:
            d = dec[js["materials"][p["material"]]["name"]]
            at = {k: read(djs, dbin, v) for k, v in d["attributes"].items() if k in p["attributes"]}
            at["JOINTS_0"] = remap[at["JOINTS_0"].astype(np.int64)]
            new.append((p, at, read(djs, dbin, d["indices"]).ravel()))
    out = npk.Out(js, bin_)
    for p, at, idx in new:
        for k, v in at.items():
            ty = "SCALAR" if v.shape[1] == 1 else f"VEC{v.shape[1]}"
            if k == "JOINTS_0":
                acc = {"componentType": 5123, "type": ty}
                data = v.astype(np.uint16)
            else:
                acc = {"componentType": 5126, "type": ty}
                data = v.astype(np.float32)
            acc.update({"bufferView": out.add_view(data.tobytes()), "count": len(v)})
            if k == "POSITION":
                acc["min"], acc["max"] = data.min(0).tolist(), data.max(0).tolist()
            js["accessors"].append(acc)
            p["attributes"][k] = len(js["accessors"]) - 1
        big = int(at["POSITION"].shape[0]) > 65535
        iacc = {"componentType": 5125 if big else 5123, "type": "SCALAR", "count": len(idx)}
        iacc["bufferView"] = out.add_view(idx.astype(np.uint32 if big else np.uint16).tobytes())
        js["accessors"].append(iacc)
        p["indices"] = len(js["accessors"]) - 1
    compact(out)
    out.write(out_path)
    print(out_path, f"{out.size / 1e6:.1f} MB bin", sum(len(i) // 3 for _, _, i in new), "tris")


def compact(out):
    """Drops the accessors and buffer views nothing points at any more."""
    js = out.js
    used = set()
    for m in js["meshes"]:
        for p in m["primitives"]:
            used.update(p["attributes"].values())
            used.add(p["indices"])
    for s in js.get("skins", []):
        used.add(s["inverseBindMatrices"])
    for a in js.get("animations", []):
        for s in a["samplers"]:
            used.update((s["input"], s["output"]))
    amap = {old: i for i, old in enumerate(sorted(used))}
    accs = [js["accessors"][i] for i in sorted(used)]
    views = {a["bufferView"] for a in accs} | {i["bufferView"] for i in js.get("images", []) if "bufferView" in i}
    data = [(i, out.chunks[2 * i + 1], js["bufferViews"][i]) for i in sorted(views)]
    vmap = {old: n for n, (old, _, _) in enumerate(data)}
    out.chunks, out.size, js["bufferViews"] = [], 0, []
    for _, d, bv in data:
        out.add_view(d, bv)
    for a in accs:
        a["bufferView"] = vmap[a["bufferView"]]
    for i in js.get("images", []):
        if "bufferView" in i:
            i["bufferView"] = vmap[i["bufferView"]]
    js["accessors"] = accs
    for m in js["meshes"]:
        for p in m["primitives"]:
            p["attributes"] = {k: amap[v] for k, v in p["attributes"].items()}
            p["indices"] = amap[p["indices"]]
    for s in js.get("skins", []):
        s["inverseBindMatrices"] = amap[s["inverseBindMatrices"]]
    for a in js.get("animations", []):
        for s in a["samplers"]:
            s["input"], s["output"] = amap[s["input"]], amap[s["output"]]


if __name__ == "__main__":
    main(*sys.argv[1:4])
