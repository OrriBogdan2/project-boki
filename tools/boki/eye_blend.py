"""Blend a Meshy-painted eye patch into a Boki's live atlas: the coat keeps its own colours everywhere else.

    python3 tools/boki/eye_blend.py <live.glb> <meshy_texture.png> <out.png> [--grow 2.0]
    python3 tools/boki/eye_blend.py <live.glb> <meshy_texture.png> <out.png> --extract [--grow 1.6] [--de 14,34]
        [--sharpen 0] [--clean d[,mid|lo|hi[,core]]] [--mask mask.png]
The eye spots come from the glb's own Face mesh (the `boki_eye` primitive: one dome per side, fitted to the scan's
eyes). Every Body triangle with a vertex within `grow` x the dome radius of a dome centre is painted into a UV mask
(feathered); inside it the Meshy texture wins, outside it the live atlas. Feed `out.png` to swap_atlas.py. Meshy's
retexture must keep the original UVs (`--original-uv`).
--extract (eye only): the weight falls off with 3D distance from the dome centres (full inside the dome, zero at
`grow` x its radius), rasterised per texel through each triangle so UV seams cannot crack it; inside it only the
Meshy texels that differ from Meshy's own skin round the eye (colour distance --de lo,hi) are taken, so the live
coat's skin stays and only iris, pupil, lid line and highlights come across. No patch, no recolour. --clean d: live
texels near the eye further than d from the live skin (old painted lids or blobs) take the live skin colour first
(the ring's median, or of its darker/lighter half; only where the eye weight > core, default 0.15)."""
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


def _spots(js, blob, mats):
    eye = next(p for p in prims(js, "Face") if mats[p["material"]] == "boki_eye")
    pts = acc(js, blob, eye["attributes"]["POSITION"])
    out = []
    for side in (pts[:, 0] >= 0, pts[:, 0] < 0):
        if side.any():
            c = pts[side].mean(0)
            out.append((c, np.linalg.norm(pts[side] - c, axis=1).max()))
    return out


def _weights(js, blob, mats, grow, size):
    """Per-texel eye weight: 1 inside a dome, linear to 0 at grow x its radius (3D), barycentric in UV."""
    spots = _spots(js, blob, mats)
    wmap = np.zeros((size, size), np.float32)
    for p in prims(js, "Body"):
        if "TEXCOORD_0" not in p["attributes"]:
            continue
        pos = acc(js, blob, p["attributes"]["POSITION"])
        uv = acc(js, blob, p["attributes"]["TEXCOORD_0"]) * size
        idx = acc(js, blob, p["indices"]).reshape(-1, 3)
        w = np.zeros(len(pos), np.float32)
        for c, r in spots:
            d = np.linalg.norm(pos - c, axis=1)
            w = np.maximum(w, np.clip((r * grow - d) / (r * (grow - 1.0)), 0.0, 1.0))
        for t in idx[(w[idx] > 0).any(axis=1)]:
            a, b, c = uv[t[0]], uv[t[1]], uv[t[2]]
            x0, y0 = np.floor(np.minimum(np.minimum(a, b), c)).astype(int) - 1
            x1, y1 = np.ceil(np.maximum(np.maximum(a, b), c)).astype(int) + 1
            x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, size), min(y1, size)
            if x1 <= x0 or y1 <= y0:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
            den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(den) < 1e-9:
                continue
            l0 = ((b[1] - c[1]) * (gx - c[0]) + (c[0] - b[0]) * (gy - c[1])) / den
            l1 = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / den
            l2 = 1.0 - l0 - l1
            eps = -0.6 / max(np.linalg.norm(a - b), np.linalg.norm(b - c), np.linalg.norm(c - a), 1.0)
            ins = (l0 >= eps) & (l1 >= eps) & (l2 >= eps)
            val = np.clip(l0 * w[t[0]] + l1 * w[t[1]] + l2 * w[t[2]], 0, 1)
            sub = wmap[y0:y1, x0:x1]
            sub[ins] = np.maximum(sub[ins], val[ins])
    return wmap


def extract(glb, tex, grow=1.6, de=(14.0, 34.0), sharpen=0.0, size=2048, clean=0.0, clean_ref="mid", clean_core=0.15):
    js, blob = read_glb(glb)
    mats = [m["name"] for m in js["materials"]]
    wmap = _weights(js, blob, mats, grow, size)
    img = next(i for i in js["images"] if i["name"].endswith("_atlas"))
    v = js["bufferViews"][img["bufferView"]]
    live = Image.open(io.BytesIO(blob[v["byteOffset"] : v["byteOffset"] + v["byteLength"]])).convert("RGB")
    live = live.resize((size, size))
    new = Image.open(tex).convert("RGB").resize((size, size), Image.LANCZOS)
    if sharpen > 0:
        new = new.filter(ImageFilter.UnsharpMask(2, int(sharpen * 100), 2))
    n = np.asarray(new, np.float32)
    ring = (wmap > 0.02) & (wmap < 0.6)  # Meshy's skin round the eye
    skin = np.median(n[ring], axis=0) if ring.any() else n[wmap > 0].mean(0)
    dist = np.linalg.norm(n - skin, axis=2)
    a = np.clip((dist - de[0]) / (de[1] - de[0]), 0, 1).astype(np.float32)
    # no blur or dilate in UV space: the atlas is cut into one island per triangle, so a UV filter bleeds into
    # unrelated parts of the coat (the cracks and smears of the first pass)
    alpha = (a * wmap * 255).astype(np.uint8)
    mask = Image.fromarray(alpha)
    if clean > 0:  # the live coat's old painted eye marks (closed lids, blobs) near the eye: fill with its own skin
        lv = np.asarray(live, np.float32)
        pool = lv[ring] if ring.any() else lv[wmap > 0]
        if clean_ref != "mid":  # fill from the darker/lighter half of the ring (a dark eye patch keeps its dark)
            lum = pool.sum(1)
            pool = pool[lum <= np.median(lum)] if clean_ref == "lo" else pool[lum >= np.median(lum)]
        lskin = np.median(pool, axis=0)
        odd = (np.linalg.norm(lv - lskin, axis=2) > clean) & (wmap > clean_core)
        k = np.where(odd, np.clip(wmap * 1.5, 0, 1), 0)[..., None]
        live = Image.fromarray((lv * (1 - k) + lskin * k).astype(np.uint8))
    return Image.composite(new, live, mask), int((alpha > 8).sum()), alpha.mean() / 255, mask


if __name__ == "__main__":
    a = sys.argv[1:]
    if "--extract" in a:
        grow = float(a[a.index("--grow") + 1]) if "--grow" in a else 1.6
        de = tuple(float(x) for x in a[a.index("--de") + 1].split(",")) if "--de" in a else (14.0, 34.0)
        sh = float(a[a.index("--sharpen") + 1]) if "--sharpen" in a else 0.0
        cl = (a[a.index("--clean") + 1] if "--clean" in a else "0").split(",")
        ref, core = (cl[1] if len(cl) > 1 else "mid"), (float(cl[2]) if len(cl) > 2 else 0.15)
        out, n, frac, mask = extract(a[0], a[1], grow, de, sh, clean=float(cl[0]), clean_ref=ref, clean_core=core)
        out.save(a[2])
        if "--mask" in a:
            mask.save(a[a.index("--mask") + 1])
        print("texels", n, "mask %.3f%% of the atlas" % (frac * 100))
    else:
        grow = float(a[a.index("--grow") + 1]) if "--grow" in a else 2.0
        out, n, frac = blend(a[0], a[1], grow)
        out.save(a[2])
        print("tris", n, "mask %.2f%% of the atlas" % (frac * 100))
