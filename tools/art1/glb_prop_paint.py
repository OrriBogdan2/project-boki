"""Repaints a Hunter's scripted props (flat-UV pieces: Tarek's eye-stones and fist shards, tarek_scan.py) from a v95
body material, with no Blender. A v95 port (v95_to_game.py) gives the body a new atlas but keeps the game's props on
the old one: Tarek's stones kept the old scan's grey texel while his v95 arm is cobalt slate (owner 11-17: his stones
are cobalt like his arm, never grey). Each prop part on `--from` moves onto `--to` (the arm's material, so the same toon
slot and paint) and every UV of it lands on one texel of that atlas: a calm patch (low spread round it, so mipmaps keep
the colour) of the stone's own hue with no emission, at the stone's median brightness. The old material then goes
with the textures, images and bytes only it used (glb_drop_mats.drop). Other parts (the eyes' glow) stay as they are.
Run: python3 tools/art1/glb_prop_paint.py IN.glb OUT.glb --meshes eye_stone,shard --from leather-body.001 --to metal-v95
"""

import argparse
import io

import numpy as np
from glb_add_clips import prune, read, write
from glb_drop_mats import drop
from PIL import Image

WIN = 7  # texels each way a picked texel's patch spans (mip 3 still reads the same colour)


def acc(j, b, i):
    a = j["accessors"][i]
    assert a["componentType"] == 5126 and a["type"] == "VEC2", "a UV accessor must be float VEC2"
    bv = j["bufferViews"][a["bufferView"]]
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    assert bv.get("byteStride", 8) == 8, "interleaved UVs"
    return off, np.frombuffer(bytes(b[off : off + a["count"] * 8]), np.float32).reshape(-1, 2)


def image(j, b, tex_i):
    bv = j["bufferViews"][j["images"][j["textures"][tex_i]["source"]]["bufferView"]]
    off = bv.get("byteOffset", 0)
    return np.asarray(Image.open(io.BytesIO(bytes(b[off : off + bv["byteLength"]]))).convert("RGB")).astype(np.float32)


def texel(im, uv):
    h, w = im.shape[:2]
    return (uv[:, 1] * h).astype(int) % h, (uv[:, 0] * w).astype(int) % w


def pick(j, b, mat_i):
    """The UV of a calm, unlit texel of the material's dominant hue at its median brightness, from its own faces."""
    m = j["materials"][mat_i]
    base = image(j, b, m["pbrMetallicRoughness"]["baseColorTexture"]["index"])
    emit = image(j, b, m["emissiveTexture"]["index"]) if "emissiveTexture" in m else None
    uv = np.concatenate(
        [
            acc(j, b, p["attributes"]["TEXCOORD_0"])[1]
            for me in j["meshes"]
            for p in me["primitives"]
            if p.get("material") == mat_i
        ]
    )
    y, x = texel(base, uv)
    col = base[y, x]
    hue = np.median(col / np.maximum(col.sum(1, keepdims=True), 1.0), 0)  # its stone's chroma (rgb shares)
    ok = np.abs(col / np.maximum(col.sum(1, keepdims=True), 1.0) - hue).max(1) < 0.03
    if emit is not None:
        ey, ex = texel(emit, uv)
        ok &= emit[ey, ex].max(1) < 12.0
    h, w = base.shape[:2]
    ok &= (y >= WIN) & (y < h - WIN) & (x >= WIN) & (x < w - WIN)
    cand = np.nonzero(ok)[0]
    assert len(cand), "no unlit texel of the stone's hue"
    spread = np.array([base[y[i] - WIN : y[i] + WIN + 1, x[i] - WIN : x[i] + WIN + 1].std((0, 1)).max() for i in cand])
    calm = cand[spread <= np.percentile(spread, 20)]
    lum = col[calm].mean(1)
    i = calm[np.argsort(lum)[len(lum) // 2]]
    return ((x[i] + 0.5) / w, (y[i] + 0.5) / h), col[i]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--meshes", required=True)
    ap.add_argument("--from", dest="old", required=True)
    ap.add_argument("--to", required=True)
    a = ap.parse_args()
    j, b = read(a.src)
    names = [m.get("name") for m in j["materials"]]
    old, to = names.index(a.old), names.index(a.to)
    uv, rgb = pick(j, b, to)
    parts = [
        p
        for m in j["meshes"]
        if m.get("name") in a.meshes.split(",")
        for p in m["primitives"]
        if p.get("material") == old
    ]
    assert parts, "no prop part on %s" % a.old
    mine = {p["attributes"]["TEXCOORD_0"] for p in parts}
    others = {p["attributes"].get("TEXCOORD_0") for m in j["meshes"] for p in m["primitives"] if p not in parts}
    assert not mine & others, "a prop's UVs are shared with another part"
    for i in mine:
        off, cur = acc(j, b, i)
        b[off : off + cur.nbytes] = np.tile(np.float32(uv), (len(cur), 1)).tobytes()
        j["accessors"][i].update(min=[float(v) for v in np.float32(uv)], max=[float(v) for v in np.float32(uv)])
    for p in parts:
        p["material"] = to
    gone, _, _ = drop(j, [a.old])
    write(a.dst, j, prune(j, b))
    print(
        "glb_prop_paint: %d parts -> %s at uv %.4f,%.4f rgb %s; dropped %s; images left %s"
        % (len(parts), a.to, uv[0], uv[1], [int(v) for v in rgb], gone, [im.get("name") for im in j.get("images", [])])
    )


if __name__ == "__main__":
    main()
