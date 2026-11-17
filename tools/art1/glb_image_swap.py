#!/usr/bin/env python3
"""glb_image_swap.py IN.glb IMAGE_NAME NEW.jpg OUT.glb
Put NEW.jpg in place of the embedded image named IMAGE_NAME, touching nothing else (mesh, skin, clips, materials).
For a repaint on the same master (same mesh and UVs: Motley's r3 tail, 11-17), where a v95_to_game re-port would
re-fit and re-weight the body. The BIN is rebuilt with the views in order; offsets after the image shift."""
import json
import struct
import sys


def load(f):
    b = open(f, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + n])
    o = 20 + n
    return j, b[o + 8:o + 8 + struct.unpack("<I", b[o:o + 4])[0]]


def main(src, name, img, out):
    j, binary = load(src)
    hit = [i for i in j["images"] if i.get("name") == name]
    if len(hit) != 1:
        sys.exit("glb_image_swap: %d images named %s" % (len(hit), name))
    target = hit[0]["bufferView"]
    new = bytearray()
    for k, v in enumerate(j["bufferViews"]):
        data = open(img, "rb").read() if k == target else binary[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]]
        new += b"\0" * (-len(new) % 4)
        v["byteOffset"] = len(new)
        v["byteLength"] = len(data)
        new += data
    new += b"\0" * (-len(new) % 4)
    j["buffers"][0]["byteLength"] = len(new)
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    with open(out, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 28 + len(js) + len(new)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(new), 0x004E4942) + bytes(new))


if __name__ == "__main__":
    main(*sys.argv[1:5])
