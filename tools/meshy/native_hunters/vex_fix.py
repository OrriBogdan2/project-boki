"""Vex r5 -> game-ready Meshy-native base (native-next-1122). Four fixes on the rigged master, nothing else:
  1. the gatling's loose ammo-belt hoop (gold links standing out beside the arm) is deleted: triangles whose texels
     sit in the gold area of the gatling atlas (box-blurred hue mask) plus the shreds those leave among the links;
  2. the three prop materials lose their normal map (the game's toon pass reads it black on this mesh: the gatling
     and the hoop drew as black solids);
  3. the body atlas is regraded by hue band (the toon pass lifts it, so the raw r5 grade read neon): hair green
     darker and greener, jacket yellow a notch less lemon;
  4. materials are renamed "<slot>-<tag>" so warden_look.json's slots (nbody, ngun, ...) grade them on their own.

  python3 vex_fix.py OUT.glb IN.glb   (numpy, scipy, PIL)
"""

import io
import json
import struct
import sys

import numpy as np
from PIL import Image, ImageFilter
from scipy.spatial import cKDTree

sys.path.insert(0, __file__.rsplit("/", 2)[0])
import native_pack as npk

BLUR, THRESH, RAD, NEIGH, ITERS = 6, 0.5, 0.02, 30, 3
# (hue lo, hue hi, min sat) -> (hue shift deg, sat x, val x): hair, jacket
GRADE = [((65, 150, 0.35), (8.0, 0.95, 0.85)), ((38, 65, 0.5), (-4.0, 0.92, 0.95))]
RENAME = {"BakedMaterial": "nbody-vex", "Material_0": "narm-vex", "Material_0.003": "nring-vex", "Material_0.002": "ngun-vex"}


def grade_body(js, bn):
    """Re-encodes the body atlas with GRADE applied; returns the new bin (the old image bytes stay orphaned)."""
    mat = next(m for m in js["materials"] if m["name"] == "BakedMaterial")
    img = js["images"][js["textures"][mat["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]]
    im = Image.open(io.BytesIO(npk.view_bytes(js, bn, img["bufferView"]))).convert("RGB")
    a = np.asarray(im).astype(np.float32) / 255
    hsv = np.asarray(im.convert("HSV")).astype(np.float32)
    hue, sat = hsv[..., 0] * 360 / 255, hsv[..., 1] / 255
    mx, mn = a.max(-1), a.min(-1)
    val = mx
    h = hue.copy()
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    for (lo, hi, smin), (dh, ds, dv) in GRADE:
        m = (hue >= lo) & (hue < hi) & (sat >= smin)
        m = np.asarray(Image.fromarray(m.astype(np.uint8) * 255).filter(ImageFilter.GaussianBlur(2))).astype(np.float32) / 255
        h = h + m * dh
        s = s * (1 + m * (ds - 1))
        val = val * (1 + m * (dv - 1))
    # hsv -> rgb
    hh = (h % 360) / 60
    c = val * s
    x = c * (1 - np.abs(hh % 2 - 1))
    z = np.zeros_like(c)
    k = hh.astype(int) % 6
    r = np.choose(k, [c, x, z, z, x, c]); g = np.choose(k, [x, c, c, x, z, z]); b = np.choose(k, [z, z, x, c, c, x])
    out = np.stack([r, g, b], -1) + (val - c)[..., None]
    buf = io.BytesIO()
    Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)).save(buf, "JPEG", quality=93)
    data = buf.getvalue()
    bn = bytearray(bn)
    bn += b"\0" * ((4 - len(bn) % 4) % 4)
    bv = js["bufferViews"][img["bufferView"]]
    bv["byteOffset"], bv["byteLength"] = len(bn), len(data)
    bn += data
    return bn


def main(dst, src):
    b = open(src, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    js = json.loads(b[20 : 20 + n])
    bn = bytearray(b[20 + n + 8 :])
    gun = next(m for m in js["meshes"] if m["name"] == "Mesh_0.002")["primitives"][0]
    pos = npk.floats(js, bn, gun["attributes"]["POSITION"])
    uv = npk.floats(js, bn, gun["attributes"]["TEXCOORD_0"])
    tex = js["materials"][gun["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    img = js["images"][js["textures"][tex]["source"]]
    im = Image.open(io.BytesIO(npk.view_bytes(js, bn, img["bufferView"]))).convert("RGB")
    w, h = im.size
    hsv = np.asarray(im.convert("HSV")).astype(float)
    hue, sat, val = hsv[..., 0] / 255 * 360, hsv[..., 1] / 255, hsv[..., 2] / 255
    gold = ((hue > 33) & (hue < 70) & (sat > 0.3) & (val > 0.25)).astype(np.uint8) * 255
    g = np.asarray(Image.fromarray(gold).filter(ImageFilter.BoxBlur(BLUR))).astype(float) / 255
    ia = js["accessors"][gun["indices"]]
    bv = js["bufferViews"][ia["bufferView"]]
    dt = {5123: np.uint16, 5125: np.uint32}[ia["componentType"]]
    off = bv.get("byteOffset", 0) + ia.get("byteOffset", 0)
    idx = np.frombuffer(bytes(bn[off : off + ia["count"] * np.dtype(dt).itemsize]), dt).reshape(-1, 3).astype(int)
    cuv = uv[idx].mean(1)
    score = g[np.clip((cuv[:, 1] * h).astype(int), 0, h - 1), np.clip((cuv[:, 0] * w).astype(int), 0, w - 1)]
    rm = score > THRESH
    cen = pos[idx].mean(1)
    for _ in range(ITERS):
        nn = cKDTree(cen[rm]).query_ball_point(cen, RAD, return_length=True)
        rm |= nn >= NEIGH
    keep = ~rm
    print("gatling tris", len(idx), "->", int(keep.sum()))
    new = idx[keep].astype(dt).tobytes()
    bn[off : off + len(new)] = new
    ia["count"] = int(keep.sum() * 3)
    bn = grade_body(js, bn)
    for m in js["materials"]:
        m.pop("normalTexture", None)
        m["name"] = RENAME.get(m["name"], m["name"])
    j = json.dumps(js, separators=(",", ":")).encode()
    j += b" " * ((4 - len(j) % 4) % 4)
    bn = bytes(bn)
    out = struct.pack("<I", len(j)) + b"JSON" + j + struct.pack("<I", len(bn)) + b"BIN\0" + bn
    open(dst, "wb").write(b"glTF" + struct.pack("<II", 2, 12 + len(out)) + out)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
