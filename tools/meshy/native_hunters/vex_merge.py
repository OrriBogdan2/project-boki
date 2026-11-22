"""Vex: puts vex_fix.py's graded body atlas (and its slot names, no normal maps) onto another build of the same r5
rig (same UVs), e.g. the posed r7 source.   python3 vex_merge.py OUT.glb POSED.glb GRADED.glb"""

import io
import json
import struct
import sys

sys.path.insert(0, __file__.rsplit("/", 2)[0])
import native_pack as npk

RENAME = {"cloth-body": "nbody-vex", "metal-armL": "narm-vex", "brass-rings": "nring-vex", "brass-gun": "ngun-vex"}


def body_image(js, bn, name):
    mat = next(m for m in js["materials"] if m["name"] == name)
    img = js["images"][js["textures"][mat["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]]
    return mat, img, npk.view_bytes(js, bn, img["bufferView"])


def main(dst, posed, graded):
    gjs, gbn = npk.load(graded)
    data = bytes(body_image(gjs, gbn, "nbody-vex" if any(m["name"] == "nbody-vex" for m in gjs["materials"]) else "BakedMaterial")[2])
    b = open(posed, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    js = json.loads(b[20 : 20 + n])
    bn = bytearray(b[20 + n + 8 :])
    _, img, _ = body_image(js, bn, "cloth-body")
    bn += b"\0" * ((4 - len(bn) % 4) % 4)
    bv = js["bufferViews"][img["bufferView"]]
    bv["byteOffset"], bv["byteLength"] = len(bn), len(data)
    bn += data
    for m in js["materials"]:
        m.pop("normalTexture", None)
        m["name"] = RENAME.get(m["name"], m["name"])
    j = json.dumps(js, separators=(",", ":")).encode()
    j += b" " * ((4 - len(j) % 4) % 4)
    out = struct.pack("<I", len(j)) + b"JSON" + j + struct.pack("<I", len(bn)) + b"BIN\0" + bytes(bn)
    open(dst, "wb").write(b"glTF" + struct.pack("<II", 2, 12 + len(out)) + out)


if __name__ == "__main__":
    main(*sys.argv[1:4])
