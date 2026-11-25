"""Bleeds a material's UV islands outward by N texels in its own embedded image (the texels just outside each island
take the nearest island texel's colour), so mips and bilinear taps at an island's border stop pulling in the
neighbouring islands' paint. Only for an image no other material samples (it asserts that), so the texels it
overwrites are unused (past the ring: the islands' mean colour); the mesh, UVs and every other byte group stay the same (the BIN is repacked, glb_image_swap).
Meeko's wings (11-24, PLAN meeko-comp-plan-1124 4C): their tiny islands on a copy of the body atlas showed a pale
broken line along every wing edge at the eye-level camera.
Run: python3 tools/art1/glb_island_dilate.py IN.glb OUT.glb --material=meshy_textured-wing [--px=8] [--quality=95]"""

import io
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import distance_transform_edt

sys.path.insert(0, os.path.dirname(__file__))
import glb_image_swap  # noqa: E402


def main():
    src, out = sys.argv[1], sys.argv[2]
    opt = dict(x[2:].split("=", 1) for x in sys.argv[3:] if x.startswith("--"))
    mat_name, px, quality = opt["material"], int(opt.get("px", 8)), int(opt.get("quality", 95))
    j, binary = glb_image_swap.load(src)
    mi = [i for i, m in enumerate(j["materials"]) if m.get("name") == mat_name]
    assert len(mi) == 1, "no single material " + mat_name
    tex = j["materials"][mi[0]]["pbrMetallicRoughness"]["baseColorTexture"]
    image = j["textures"][tex["index"]]["source"]
    users = []
    for m in j["materials"]:
        t = m.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if t and j["textures"][t["index"]]["source"] == image:
            users.append(m["name"])
    assert users == [mat_name], "image %d is shared: %s" % (image, users)
    view = j["images"][image]["bufferView"]
    bv = j["bufferViews"][view]
    raw = binary[bv.get("byteOffset", 0) : bv.get("byteOffset", 0) + bv["byteLength"]]
    img = Image.open(io.BytesIO(raw)).convert("RGB")
    w, h = img.size

    def acc(i):
        a = j["accessors"][i]
        v = j["bufferViews"][a["bufferView"]]
        nc = {"SCALAR": 1, "VEC2": 2}[a["type"]]
        dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16}[a["componentType"]]
        assert not v.get("byteStride") or v["byteStride"] == np.dtype(dt).itemsize * nc
        off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
        return (
            np.frombuffer(binary, dt, a["count"] * nc, off).reshape(-1, nc)
            if nc > 1
            else np.frombuffer(binary, dt, a["count"], off)
        )

    mask = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask)
    tris = 0
    for mesh in j["meshes"]:
        for p in mesh["primitives"]:
            if p.get("material") != mi[0]:
                continue
            uv = acc(p["attributes"]["TEXCOORD_%d" % tex.get("texCoord", 0)]) * (w, h)
            for t in acc(p["indices"]).reshape(-1, 3):
                draw.polygon([tuple(uv[k]) for k in t], fill=255)
                tris += 1
    inside = np.array(mask) > 0
    dist, (iy, ix) = distance_transform_edt(~inside, return_indices=True)
    a = np.array(img)
    ring = (~inside) & (dist <= px)
    a[ring] = a[iy[ring], ix[ring]]
    # (and every texel past the ring, unused by any surface, the islands' mean: the low mips blend toward it, not
    # toward the other parts' paint, and the JPEG shrinks)
    a[dist > px] = a[inside].mean(0).round().astype(np.uint8)
    buf = io.BytesIO()
    Image.fromarray(a).save(buf, "JPEG", quality=quality, subsampling=0)
    glb_image_swap.write(j, binary, view, buf.getvalue(), out)
    print(
        "glb_island_dilate: %s, %d tris, islands %.1f%% of %dx%d, %d texels bled (%d px)"
        % (mat_name, tris, 100 * inside.mean(), w, h, int(ring.sum()), px)
    )


if __name__ == "__main__":
    main()
