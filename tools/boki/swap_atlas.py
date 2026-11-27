"""Swap the colour atlas inside a Boki game glb for a new image, leaving mesh, rig, face and normal map as they are.

Used by the eye paint pass (Meshy retexture of the coat on its own UVs, docs/art/kin/RIGGED_BOKI.md).
    python3 tools/boki/swap_atlas.py art/kin/<id>/<id>.glb new_texture.png [--size 2048] [--quality 88]
The atlas is the image named `<id>_atlas`; it is re-encoded as WebP at --size and written back into the glb."""
import io
import json
import struct
import sys

from PIL import Image


def read_glb(path):
    data = open(path, "rb").read()
    n = struct.unpack("<I", data[12:16])[0]
    js = json.loads(data[20 : 20 + n])
    off = 20 + n
    blen = struct.unpack("<I", data[off : off + 4])[0]
    return js, data[off + 8 : off + 8 + blen]


def write_glb(path, js, blob):
    j = json.dumps(js, separators=(",", ":")).encode()
    j += b" " * (-len(j) % 4)
    blob += b"\0" * (-len(blob) % 4)
    total = 12 + 8 + len(j) + 8 + len(blob)
    with open(path, "wb") as f:
        f.write(b"glTF" + struct.pack("<II", 2, total))
        f.write(struct.pack("<I", len(j)) + b"JSON" + j)
        f.write(struct.pack("<I", len(blob)) + b"BIN\0" + blob)


def swap(path, png, size=2048, quality=88):
    js, blob = read_glb(path)
    img = next(i for i in js["images"] if i["name"].endswith("_atlas"))
    buf = io.BytesIO()
    Image.open(png).convert("RGB").resize((size, size), Image.LANCZOS).save(buf, "WEBP", quality=quality)
    views = js["bufferViews"]
    chunks = {}
    for i, v in enumerate(views):
        start = v.get("byteOffset", 0)
        chunks[i] = buf.getvalue() if i == img["bufferView"] else blob[start : start + v["byteLength"]]
    out = b""
    for i, v in enumerate(views):
        out += b"\0" * (-len(out) % 4)
        v["byteOffset"] = len(out)
        v["byteLength"] = len(chunks[i])
        out += chunks[i]
    js["buffers"][0]["byteLength"] = len(out)
    write_glb(path, js, out)


if __name__ == "__main__":
    a = sys.argv[1:]
    size = int(a[a.index("--size") + 1]) if "--size" in a else 2048
    q = int(a[a.index("--quality") + 1]) if "--quality" in a else 88
    swap(a[0], a[1], size, q)
