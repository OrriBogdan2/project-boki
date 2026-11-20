"""Moves part of a material's triangles to a new material (a copy of it under a new name), picked by the paint under
each triangle: its slot then takes its own warden_look.json "slots" entry. The vertex data stay shared; only the
index list is split (the moved triangles get a new index accessor at the end of the binary chunk).
Tenzo r3: his pants and sash shared "cloth-v95"; the look's cloth desat (for the orange sash) greyed the dark maroon
pants to near black. cloth-v95 -> cloth-pants for the maroon texels gives the pants their own look.
Rule: the texel at each triangle's centre, hue in [--h-lo, 1] or [0, --h-hi], value <= --v-max, saturation >= --s-min,
the vertex height (y) below --y-max; then --vote passes of a majority vote over neighbouring triangles (no speckle).
Run: python3 tools/art1/glb_mat_split.py IN.glb OUT.glb MATERIAL NEW_NAME [--h-lo 0.85] [--h-hi 0.04] [--v-max 0.42]
     [--s-min 0.12] [--y-max 9] [--vote 3]"""

import argparse
import copy
import io
import json
import struct

import numpy as np
from PIL import Image

NP = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read(path):
    b = open(path, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20 : 20 + n])
    m = struct.unpack("<I", b[20 + n : 24 + n])[0]
    return j, bytearray(b[28 + n : 28 + n + m])


def accessor(j, bin_, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    w = WIDTH[a["type"]]
    x = np.frombuffer(bin_, NP[a["componentType"]], a["count"] * w, bv.get("byteOffset", 0) + a.get("byteOffset", 0))
    return x.reshape(-1, w) if w > 1 else x


def image(j, bin_, mat):
    t = j["textures"][mat["pbrMetallicRoughness"]["baseColorTexture"]["index"]]
    bv = j["bufferViews"][j["images"][t["source"]]["bufferView"]]
    o = bv.get("byteOffset", 0)
    return np.asarray(Image.open(io.BytesIO(bytes(bin_[o : o + bv["byteLength"]]))).convert("RGB"), np.float32) / 255.0


def vote(tris, pick, passes):
    """Each pass, a triangle takes the side most of its vertex-sharing neighbours are on."""
    nv = tris.max() + 1
    for _ in range(passes):
        share = np.zeros(nv)
        count = np.zeros(nv)
        for k in range(3):
            np.add.at(share, tris[:, k], pick)
            np.add.at(count, tris[:, k], 1)
        frac = (share / np.maximum(count, 1))[tris].mean(1)
        pick = np.where(frac > 0.6, 1.0, np.where(frac < 0.4, 0.0, pick))
    return pick > 0.5


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("mat")
    ap.add_argument("new")
    ap.add_argument("--h-lo", type=float, default=0.85)
    ap.add_argument("--h-hi", type=float, default=0.04)
    ap.add_argument("--v-max", type=float, default=0.42)
    ap.add_argument("--s-min", type=float, default=0.12)
    ap.add_argument("--y-max", type=float, default=9.0)
    ap.add_argument("--vote", type=int, default=3)
    a = ap.parse_args()
    j, bin_ = read(a.src)
    names = [m.get("name") for m in j["materials"]]
    if a.mat not in names:
        raise SystemExit("glb_mat_split: no material " + a.mat)
    mi = names.index(a.mat)
    j["materials"].append(copy.deepcopy(j["materials"][mi]))
    j["materials"][-1]["name"] = a.new
    img = image(j, bin_, j["materials"][mi])
    h, w = img.shape[:2]
    moved = 0
    for mesh in j["meshes"]:
        for p in list(mesh["primitives"]):
            if p.get("material") != mi:
                continue
            tris = accessor(j, bin_, p["indices"]).reshape(-1, 3).astype(np.int64)
            uv = accessor(j, bin_, p["attributes"]["TEXCOORD_0"])[tris].mean(1)
            y = accessor(j, bin_, p["attributes"]["POSITION"])[tris][:, :, 1].mean(1)
            c = img[np.clip((uv[:, 1] * h).astype(int), 0, h - 1), np.clip((uv[:, 0] * w).astype(int), 0, w - 1)]
            v = c.max(1)
            s = (v - c.min(1)) / np.maximum(v, 1e-6)
            r, g, b = c.T
            d = np.maximum(v - c.min(1), 1e-6)
            hue = np.where(v == r, ((g - b) / d) % 6, np.where(v == g, (b - r) / d + 2, (r - g) / d + 4)) / 6.0
            pick = ((hue >= a.h_lo) | (hue <= a.h_hi)) & (v <= a.v_max) & (s >= a.s_min) & (y <= a.y_max)
            pick = vote(tris, pick.astype(float), a.vote)
            if not pick.any():
                continue
            raw = tris[pick].astype(np.uint32).tobytes()
            keep = tris[~pick].astype(np.uint32).tobytes()
            for data, prim in ((keep, p), (raw, None)):
                while len(bin_) % 4:
                    bin_.append(0)
                j["bufferViews"].append({"buffer": 0, "byteOffset": len(bin_), "byteLength": len(data), "target": 34963})
                bin_ += data
                j["accessors"].append({"bufferView": len(j["bufferViews"]) - 1, "componentType": 5125,
                                       "count": len(data) // 4, "type": "SCALAR"})
                if prim is not None:
                    prim["indices"] = len(j["accessors"]) - 1
                else:
                    q = copy.deepcopy(p)
                    q["indices"] = len(j["accessors"]) - 1
                    q["material"] = len(j["materials"]) - 1
                    mesh["primitives"].append(q)
            moved += int(pick.sum())
            print("glb_mat_split: %s %d of %d triangles -> %s" % (mesh.get("name"), pick.sum(), len(tris), a.new))
    if not moved:
        raise SystemExit("glb_mat_split: no triangle matched")
    while len(bin_) % 4:
        bin_.append(0)
    j["buffers"][0]["byteLength"] = len(bin_)
    s = json.dumps(j, separators=(",", ":")).encode()
    s += b" " * ((-len(s)) % 4)
    total = 12 + 8 + len(s) + 8 + len(bin_)
    with open(a.out, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(s), 0x4E4F534A) + s)
        f.write(struct.pack("<II", len(bin_), 0x004E4942) + bytes(bin_))


if __name__ == "__main__":
    main()
