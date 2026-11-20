"""Moves part of one material's triangles in a shipped Hero .glb onto a new material (a new toon slot), by height band
and painted colour, in place of a rebuild: Motley's galaxy tail was painted into "cloth-v95", so the game drew it as
flat cloth; on "void-tail-v95" WardenGlb draws it with the starfield shader (hero_void.gdshader) like the turnaround.
Nothing else changes: the new part shares the old part's vertex accessors (positions, UVs, skin weights), only the
index list is split, and the new material is a copy of the old one (same atlas) under the new name. Clips, skin,
images and every other part keep their bytes.
Each triangle is tested at its centroid (rest pose, glTF frame: +Y up) and the atlas colour at its UV centroid; then
`vote` rounds of neighbour majority (over welded positions) smooth the edge so no single facets flip.
Run: python3 tools/art1/glb_slot_split.py IN.glb OUT.glb FROM_MAT TO_MAT [--y a,b] [--x a,b] [--z a,b] [--h a,b]
     [--s a,b] [--v a,b] [--vote 3] [--preview out.png]
Prints the triangle counts moved."""
import argparse
import copy
import io
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from glb_add_clips import prune, read, write  # noqa: E402

N_COMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
DT = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}


def acc(j, b, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    n = N_COMP[a["type"]]
    dt = np.dtype(DT[a["componentType"]])
    o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    st = bv.get("byteStride", n * dt.itemsize)
    raw = np.frombuffer(bytes(b[o:o + st * (a["count"] - 1) + n * dt.itemsize]), np.uint8)
    rows = np.lib.stride_tricks.as_strided(raw, (a["count"], n * dt.itemsize), (st, 1))
    out = np.frombuffer(rows.copy().tobytes(), dt).reshape(a["count"], n).astype(np.float64)
    if a.get("normalized"):
        out /= np.iinfo(dt).max
    return out


def atlas(j, b, mat):
    from PIL import Image
    tex = j["materials"][mat].get("pbrMetallicRoughness", {}).get("baseColorTexture")
    im = j["images"][j["textures"][tex["index"]]["source"]]
    bv = j["bufferViews"][im["bufferView"]]
    o = bv.get("byteOffset", 0)
    return np.asarray(Image.open(io.BytesIO(bytes(b[o:o + bv["byteLength"]]))).convert("RGB"), np.float32) / 255.0


def hsv(c):
    mx, mn = c.max(1), c.min(1)
    d = mx - mn + 1e-9
    r, g, bl = c.T
    h = np.where(mx == r, ((g - bl) / d) % 6, np.where(mx == g, (bl - r) / d + 2, (r - g) / d + 4)) / 6
    return h, np.where(mx > 0, d / (mx + 1e-9), 0), mx


def rng(s):
    return [float(v) for v in s.split(",")] if s else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("from_mat")
    ap.add_argument("to_mat")
    for k in "xyzhsv":
        ap.add_argument("--" + k)
    ap.add_argument("--vote", type=int, default=3)
    ap.add_argument("--preview")
    a = ap.parse_args()
    j, b = read(a.src)
    mats = [m.get("name") for m in j["materials"]]
    if a.to_mat in mats:
        raise SystemExit(f"{a.to_mat} already in {a.src}")
    fi = mats.index(a.from_mat)
    new = copy.deepcopy(j["materials"][fi])
    new["name"] = a.to_mat
    j["materials"].append(new)
    ni = len(j["materials"]) - 1
    moved = 0
    for mesh in j["meshes"]:
        add = []
        for pr in mesh["primitives"]:
            if pr.get("material") != fi or "indices" not in pr:
                continue
            P = acc(j, b, pr["attributes"]["POSITION"])
            UV = acc(j, b, pr["attributes"]["TEXCOORD_0"]) % 1.0
            I = acc(j, b, pr["indices"]).astype(np.int64).reshape(-1, 3)
            tex = atlas(j, b, fi)
            th, tw = tex.shape[:2]
            cen, uvc = P[I].mean(1), UV[I].mean(1)
            rgb = tex[np.clip((uvc[:, 1] * th).astype(int), 0, th - 1), np.clip((uvc[:, 0] * tw).astype(int), 0, tw - 1)]
            h, s, v = hsv(rgb)
            m = np.ones(len(I), bool)
            for key, val in (("x", cen[:, 0]), ("y", cen[:, 1]), ("z", cen[:, 2]), ("h", h), ("s", s), ("v", v)):
                r = rng(getattr(a, key))
                if r:
                    m &= (val >= r[0]) & (val <= r[1])
            # neighbour majority over welded positions (a UV seam splits vertices, not the surface)
            _, weld = np.unique(np.round(P, 5), axis=0, return_inverse=True)
            W = weld.reshape(-1)[I]
            for _ in range(a.vote):
                vs = np.zeros(W.max() + 1)
                vc = np.zeros(W.max() + 1)
                np.add.at(vs, W.reshape(-1), np.repeat(m.astype(float), 3))
                np.add.at(vc, W.reshape(-1), 1.0)
                frac = (vs / np.maximum(vc, 1))[W].mean(1)
                m = frac > 0.5
            if not m.any():
                continue
            keep_i, move_i = I[~m].reshape(-1), I[m].reshape(-1)
            for idx, target in ((keep_i, pr), (move_i, None)):
                small = len(P) < 65536      # (the source's own width: a 16-bit list stays 16-bit)
                arr = idx.astype(np.uint16 if small else np.uint32).tobytes()
                b += b"\0" * (-len(b) % 4)
                j["bufferViews"].append({"buffer": 0, "byteOffset": len(b), "byteLength": len(arr), "target": 34963})
                b += arr
                j["accessors"].append({"bufferView": len(j["bufferViews"]) - 1, "componentType": 5123 if small else 5125,
                                       "count": int(len(idx)), "type": "SCALAR"})
                if target is not None:
                    target["indices"] = len(j["accessors"]) - 1
                else:
                    np_ = copy.deepcopy(pr)
                    np_["indices"] = len(j["accessors"]) - 1
                    np_["material"] = ni
                    add.append(np_)
            moved += int(m.sum())
            print(f"SPLIT {mesh.get('name')}: {a.from_mat} {len(I)} tris -> keep {int((~m).sum())}, {a.to_mat} {int(m.sum())}")
            if a.preview:
                from PIL import Image
                S = 700
                im = np.full((S, S * 2, 3), 0.3, np.float32)
                for k, (xx, dd) in enumerate(((cen[:, 0], cen[:, 2]), (cen[:, 2], -cen[:, 0]))):
                    px = ((xx + 0.9) / 1.8 * S).astype(int) + k * S
                    py = ((1.85 - cen[:, 1]) / 1.9 * S).astype(int)
                    col = np.where(m[:, None], np.array([0.1, 1.0, 0.3]), rgb)
                    for q in np.argsort(-dd):
                        im[max(py[q] - 1, 0):py[q] + 2, max(px[q] - 1, 0):px[q] + 2] = col[q]
                Image.fromarray((im * 255).astype(np.uint8)).save(a.preview)
        mesh["primitives"] += add
    j["buffers"][0]["byteLength"] = len(b)
    write(a.dst, j, prune(j, b))      # (the split part's old index list goes)
    print("MOVED", moved)


if __name__ == "__main__":
    main()
