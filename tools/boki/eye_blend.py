"""Blend a Meshy-painted eye patch into a Boki's live atlas: the coat keeps its own colours everywhere else.

    python3 tools/boki/eye_blend.py <live.glb> <meshy_texture.png> <out.png> [--grow 2.0]
The eye spots come from the glb's own Face mesh (the `boki_eye` primitive: one dome per side, fitted to the scan's
eyes). Every Body triangle with a vertex within `grow` x the dome radius of a dome centre is painted into a UV mask
(feathered); inside it the Meshy texture wins, outside it the live atlas. Feed `out.png` to swap_atlas.py. Meshy's
retexture must keep the original UVs (`--original-uv`)."""
import io
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from swap_atlas import read_glb

NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}


def acc(js, blob, i):
    a = js["accessors"][i]
    v = js["bufferViews"][a["bufferView"]]
    dt = {5126: "<f4", 5123: "<u2", 5125: "<u4"}[a["componentType"]]
    n = NC[a["type"]]
    off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    return np.frombuffer(blob, dtype=dt, count=a["count"] * n, offset=off).reshape(a["count"], n)


def prims(js, name):
    mesh = next(m for m in js["meshes"] if m["name"] == name)
    return mesh["primitives"]


def blend(glb, tex, grow=2.0, size=2048):
    js, blob = read_glb(glb)
    mats = [m["name"] for m in js["materials"]]
    eye = next(p for p in prims(js, "Face") if mats[p["material"]] == "boki_eye")
    pts = acc(js, blob, eye["attributes"]["POSITION"])
    spots = []
    for side in (pts[:, 0] >= 0, pts[:, 0] < 0):
        if side.any():
            c = pts[side].mean(0)
            spots.append((c, np.linalg.norm(pts[side] - c, axis=1).max() * grow))
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    tris = 0
    for p in prims(js, "Body"):
        if "TEXCOORD_0" not in p["attributes"]:
            continue
        pos = acc(js, blob, p["attributes"]["POSITION"])
        uv = acc(js, blob, p["attributes"]["TEXCOORD_0"]) * size
        idx = acc(js, blob, p["indices"]).reshape(-1, 3)
        near = np.zeros(len(pos), bool)
        for c, r in spots:
            near |= np.linalg.norm(pos - c, axis=1) < r
        for t in idx[near[idx].any(axis=1)]:
            d.polygon([tuple(uv[k]) for k in t], fill=255)
            tris += 1
    mask = mask.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(3))
    img = next(i for i in js["images"] if i["name"].endswith("_atlas"))
    v = js["bufferViews"][img["bufferView"]]
    start = v["byteOffset"]
    live = Image.open(io.BytesIO(blob[start : start + v["byteLength"]])).convert("RGB").resize((size, size))
    new = Image.open(tex).convert("RGB").resize((size, size), Image.LANCZOS)
    return Image.composite(new, live, mask), tris, np.asarray(mask).mean() / 255


if __name__ == "__main__":
    a = sys.argv[1:]
    grow = float(a[a.index("--grow") + 1]) if "--grow" in a else 2.0
    out, n, frac = blend(a[0], a[1], grow)
    out.save(a[2])
    print("tris", n, "mask %.2f%% of the atlas" % (frac * 100))
