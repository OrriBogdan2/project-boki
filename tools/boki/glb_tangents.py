"""Repair degenerate TANGENT vectors in a .glb (stdlib only): the glTF validator wants unit-length xyz.

Blender writes a zero tangent on triangles whose UVs collapse. Those vertices get any unit vector perpendicular to
their normal, so the model looks the same and tools/lint_gate.py stays clean.
    python3 tools/boki/glb_tangents.py art/kin/<id>/<id>.glb ...
"""
import json
import struct
import sys


def fix(path):
    """Rewrite `path` in place; returns how many tangents were repaired."""
    with open(path, "rb") as f:
        raw = f.read()
    jlen = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20 : 20 + jlen])
    bin_at = 20 + jlen + 8
    buf = bytearray(raw[bin_at : bin_at + struct.unpack_from("<I", raw, 20 + jlen)[0]])
    fixed = 0

    def view(acc):
        a = doc["accessors"][acc]
        bv = doc["bufferViews"][a["bufferView"]]
        return a["count"], bv.get("byteOffset", 0) + a.get("byteOffset", 0), bv.get("byteStride", 16)

    for mesh in doc["meshes"]:
        for prim in mesh["primitives"]:
            at = prim["attributes"]
            if "TANGENT" not in at:
                continue
            n, t_off, t_str = view(at["TANGENT"])
            _, n_off, n_str = view(at["NORMAL"])
            for i in range(n):
                tx, ty, tz, tw = struct.unpack_from("<4f", buf, t_off + i * t_str)
                if abs((tx * tx + ty * ty + tz * tz) ** 0.5 - 1.0) < 1e-3:
                    continue
                nx, ny, nz = struct.unpack_from("<3f", buf, n_off + i * n_str)
                ax = (1.0, 0.0, 0.0) if abs(nx) < 0.9 else (0.0, 1.0, 0.0)
                v = (ax[1] * nz - ax[2] * ny, ax[2] * nx - ax[0] * nz, ax[0] * ny - ax[1] * nx)
                ln = (v[0] ** 2 + v[1] ** 2 + v[2] ** 2) ** 0.5 or 1.0
                sign = tw if tw in (-1.0, 1.0) else 1.0
                struct.pack_into("<4f", buf, t_off + i * t_str, v[0] / ln, v[1] / ln, v[2] / ln, sign)
                fixed += 1
    if fixed:
        out = raw[: bin_at] + bytes(buf) + raw[bin_at + len(buf) :]
        with open(path, "wb") as f:
            f.write(out)
    return fixed


if __name__ == "__main__":
    for p in sys.argv[1:]:
        print(p, fix(p))
