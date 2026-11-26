"""Takes the light Meshy baked into a scan Boki's coat atlas back out, down to the level the other Boki carry.

A Meshy texture is painted lit from above: tops bright, sides and underside dark. The toon shader then shades the
model again, so a coat with a strong bake reads "too shaded" (Crofthorn, 11-26: its top-facing texels are 1.96x its
down-facing ones, the Boki mean is 1.23x). This fits the bake as a smooth function of the surface normal (log
luminance on order-2 spherical harmonics, over the coat's texels), keeps `--keep` of it so the coat ends at
`--target` up/down, and scales each texel's linear RGB by one factor: hue and chroma ratios stay, only the light
moves, and the coat's mean linear luminance is unchanged (its design colour). Writes the glb's embedded atlas and
the extracted <glb>_<image>.webp beside it (the file Godot loads), which must stay byte-identical.

  python tools/boki/boki_delight.py art/kin/heatherhorn/heatherhorn.glb [--target 1.25] [--dry]
  python tools/boki/boki_delight.py --measure art/kin/*/*.glb   # up/down, side/up per species
"""
import argparse
import io
import json
import struct
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

CT = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
LUM = np.array([0.2126, 0.7152, 0.0722])
WEBP_Q = 92


def load(path):
    b = open(path, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20 : 20 + n])
    return j, bytearray(b[20 + n + 8 :])


def acc(j, b, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    n = NC[a["type"]]
    dt = np.dtype(CT[a["componentType"]])
    stride = bv.get("byteStride", n * dt.itemsize)
    raw = np.frombuffer(bytes(b), dtype=np.uint8, count=stride * (a["count"] - 1) + n * dt.itemsize, offset=off)
    out = np.lib.stride_tricks.as_strided(raw, (a["count"], n * dt.itemsize), (stride, 1)).copy()
    return out.view(dt).reshape(a["count"], n)


def coat(j, b):
    """The coat's normals, uvs and triangles, and its atlas image index."""
    mat = next(i for i, m in enumerate(j["materials"]) if m["name"] == "boki_coat")
    tex = j["materials"][mat]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    t = j["textures"][tex]
    img = t.get("extensions", {}).get("EXT_texture_webp", {}).get("source", t.get("source"))
    nrm, uv, tri = [], [], []
    base = 0
    for me in j["meshes"]:
        for pr in me["primitives"]:
            if pr.get("material") != mat:
                continue
            nrm.append(acc(j, b, pr["attributes"]["NORMAL"]))
            uv.append(acc(j, b, pr["attributes"]["TEXCOORD_0"]))
            tri.append(acc(j, b, pr["indices"]).reshape(-1, 3).astype(np.int64) + base)
            base += len(nrm[-1])
    return np.concatenate(nrm), np.concatenate(uv), np.concatenate(tri), img


def image_bytes(j, b, img):
    bv = j["bufferViews"][j["images"][img]["bufferView"]]
    o = bv.get("byteOffset", 0)
    return bytes(b[o : o + bv["byteLength"]])


def to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def sh(n):
    x, y, z = n[:, 0], n[:, 1], n[:, 2]
    return np.stack([np.ones_like(x), x, y, z, x * y, y * z, x * z, 3 * y * y - 1, x * x - z * z], 1)


def bake_ratio(n, lum):
    """The bake as measured per vertex: up-facing over down-facing mean luminance, and side over up."""
    up, dn, side = n[:, 1] > 0.6, n[:, 1] < -0.4, np.abs(n[:, 1]) < 0.3
    return lum[up].mean() / max(lum[dn].mean(), 1e-4), lum[side].mean() / max(lum[up].mean(), 1e-4)


def vertex_lum(lin, uv):
    h, w, _ = lin.shape
    x = np.clip((uv[:, 0] % 1) * w, 0, w - 1).astype(int)
    y = np.clip((uv[:, 1] % 1) * h, 0, h - 1).astype(int)
    return lin[y, x] @ LUM


def raster_normals(nrm, uv, tri, h, w):
    """Each texel's interpolated normal (zero where no coat triangle covers it)."""
    out = np.zeros((h, w, 3))
    px = np.stack([uv[:, 0] % 1 * w - 0.5, uv[:, 1] % 1 * h - 0.5], 1)
    for t in tri:
        p = px[t]
        x0, y0 = np.floor(p.min(0)).astype(int)
        x1, y1 = np.ceil(p.max(0)).astype(int)
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, w - 1), min(y1, h - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        q = np.stack([gx.ravel(), gy.ravel()], 1).astype(float)
        v0, v1 = p[1] - p[0], p[2] - p[0]
        den = v0[0] * v1[1] - v1[0] * v0[1]
        if abs(den) < 1e-12:
            continue
        d = q - p[0]
        b1 = (d[:, 0] * v1[1] - v1[0] * d[:, 1]) / den
        b2 = (v0[0] * d[:, 1] - d[:, 0] * v0[1]) / den
        b0 = 1 - b1 - b2
        m = (b0 >= -0.02) & (b1 >= -0.02) & (b2 >= -0.02)
        if not m.any():
            continue
        nn = b0[m, None] * nrm[t[0]] + b1[m, None] * nrm[t[1]] + b2[m, None] * nrm[t[2]]
        out[q[m, 1].astype(int), q[m, 0].astype(int)] = nn
    ln = np.linalg.norm(out, axis=2, keepdims=True)
    return np.where(ln > 1e-6, out / np.maximum(ln, 1e-6), 0.0)


def delight(path, target, dry):
    j, b = load(path)
    nrm, uv, tri, img = coat(j, b)
    srgb = np.asarray(Image.open(io.BytesIO(image_bytes(j, b, img))).convert("RGB")).astype(float) / 255
    lin = to_lin(srgb)
    h, w, _ = lin.shape
    before = bake_ratio(nrm, vertex_lum(lin, uv))
    tn = raster_normals(nrm, uv, tri, h, w)
    cov = np.linalg.norm(tn, axis=2) > 0.5
    lum = lin @ LUM
    ok = cov & (lum > 0.003)
    a = sh(tn[ok])
    coef, *_ = np.linalg.lstsq(a, np.log(lum[ok] + 0.003), rcond=None)
    field = np.zeros((h, w))
    field[cov] = sh(tn[cov]) @ coef
    # every uncovered texel (padding, bleed) takes its nearest covered texel's field: no seam at the chart edges
    idx = ndimage.distance_transform_edt(~cov, return_distances=False, return_indices=True)
    field = field[idx[0], idx[1]]
    field -= field[cov].mean()
    # keep k of the bake so the coat ends at `target`; the field is linear in log space, so is the ratio
    k = float(np.clip(np.log(target) / np.log(max(before[0], 1.0001)), 0.0, 1.0))
    lo, hi = 0.0, 1.0
    for _ in range(14):  # the measure is per vertex, the fit per texel: settle k on the measure itself
        f = np.exp((k - 1.0) * field)
        out = lin * f[..., None]
        out *= (lum[cov].mean() / max((out @ LUM)[cov].mean(), 1e-6))
        out /= np.maximum(out.max(2, keepdims=True), 1.0)  # a texel lifted past white keeps its hue, not its clip
        r = bake_ratio(nrm, vertex_lum(np.clip(out, 0, 1), uv))[0]
        if abs(r - target) < 0.01:
            break
        lo, hi = (k, hi) if r < target else (lo, k)
        k = (lo + hi) / 2
    clipped = float((out[cov].max(1) > 0.999).mean() - (lin[cov].max(1) > 0.999).mean())
    after = bake_ratio(nrm, vertex_lum(np.clip(out, 0, 1), uv))
    print(
        "%s: up/down %.2f -> %.2f, side/up %.2f -> %.2f, keep %.2f of the bake, factor %.2f..%.2f, newly white %.4f"
        % (path, before[0], after[0], before[1], after[1], k, f[cov].min(), f[cov].max(), clipped)
    )
    if dry:
        return
    buf = io.BytesIO()
    Image.fromarray((to_srgb(out) * 255 + 0.5).astype(np.uint8)).save(buf, "WEBP", quality=WEBP_Q, method=6)
    data = buf.getvalue()
    replace_image(j, b, img, data, path)
    name = j["images"][img]["name"]
    stem = path.rsplit("/", 1)[1][:-4]
    open(path.rsplit("/", 1)[0] + "/%s_%s.webp" % (stem, name), "wb").write(data)


def replace_image(j, b, img, data, path):
    """The image's bufferView takes `data`; every later view moves by the size change (4-byte aligned)."""
    vi = j["images"][img]["bufferView"]
    bv = j["bufferViews"][vi]
    o, old = bv.get("byteOffset", 0), bv["byteLength"]
    pad = (-len(data)) % 4
    oldpad = (-old) % 4
    new = bytes(b[:o]) + data + b"\0" * pad + bytes(b[o + old + oldpad :])
    shift = (len(data) + pad) - (old + oldpad)
    for v in j["bufferViews"]:
        if v.get("byteOffset", 0) > o:
            v["byteOffset"] = v["byteOffset"] + shift
    bv["byteLength"] = len(data)
    j["buffers"][0]["byteLength"] = len(new)
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * ((-len(js)) % 4)
    new += b"\0" * ((-len(new)) % 4)
    total = 12 + 8 + len(js) + 8 + len(new)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(new), 0x004E4942) + new)


def measure(paths):
    for p in paths:
        j, b = load(p)
        nrm, uv, _tri, img = coat(j, b)
        lin = to_lin(np.asarray(Image.open(io.BytesIO(image_bytes(j, b, img))).convert("RGB")).astype(float) / 255)
        r = bake_ratio(nrm, vertex_lum(lin, uv))
        print("%s\t%.2f\t%.2f" % (p.rsplit("/", 2)[1], r[0], r[1]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("glb", nargs="+")
    ap.add_argument("--target", type=float, default=1.25, help="up/down luminance ratio to keep (Boki mean 1.23)")
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--measure", action="store_true")
    a = ap.parse_args()
    if a.measure:
        measure(a.glb)
        return
    for p in a.glb:
        delight(p, a.target, a.dry)


if __name__ == "__main__":
    sys.exit(main())
