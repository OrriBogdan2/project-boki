"""One game .glb for a Hunter on Meshy's own skeleton (docs/art/wardens/MESHY_NATIVE.md): Meshy's rig (or its
weight-fixed hybrid) plus Meshy's own clips from its other files, bones untouched (no retarget, no rename).

  python3 tools/meshy/native_pack.py OUT.glb BASE.glb [CLIPS.glb[=name] ...] [--in-place=clip,...] [--max-tex=2048] [--max-tex-maps=1024]

- BASE keeps its nodes, skin, meshes and materials byte for byte; its own animations stay.
- Each CLIPS file adds its animations (renamed to `name` when it has one clip), its channels matched to BASE's
  nodes by name. Meshy's animate files turn the armature +90 deg about X (Z up) where the rig is Y up: the clip
  keys of the armature's children (Hips) are carried into the rig's frame, so the pose in the world is the same.
- --in-place: those clips' Hips drift along the ground (start to end) is taken out, so the game moves the body.
- --max-tex: colour textures larger than this (px) are scaled down (JPEG q90, PNG stays PNG); --max-tex-maps: the
  same for the normal and metal/roughness maps (they read at match distance only as shading).
"""

import io
import json
import struct
import sys

import numpy as np
from PIL import Image

COMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def load(path):
    b = open(path, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    js = json.loads(b[20 : 20 + n])
    return js, b[20 + n + 8 :]


def view_bytes(js, bin_, vi):
    bv = js["bufferViews"][vi]
    o = bv.get("byteOffset", 0)
    return bin_[o : o + bv["byteLength"]]


def floats(js, bin_, ai):
    a = js["accessors"][ai]
    raw = view_bytes(js, bin_, a["bufferView"])
    k = COMP[a["type"]]
    return np.frombuffer(raw, np.float32, a["count"] * k, a.get("byteOffset", 0)).reshape(a["count"], k).copy()


def qmul(a, b):
    """Quaternions (x, y, z, w), rows of b by a."""
    ax, ay, az, aw = a
    bx, by, bz, bw = b.T
    return np.stack(
        [
            aw * bx + ax * bw + ay * bz - az * by,
            aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw,
            aw * bw - ax * bx - ay * by - az * bz,
        ],
        1,
    )


def qrot(q, v):
    x, y, z, w = q
    u = np.array([x, y, z])
    return v + 2.0 * np.cross(u, np.cross(u, v) + w * v)


class Out:
    """The BASE file's json, its binary rebuilt view by view."""

    def __init__(self, js, bin_):
        self.js = js
        self.chunks = []
        self.size = 0
        old = js["bufferViews"]
        js["bufferViews"] = []
        for bv in old:
            o = bv.get("byteOffset", 0)
            self.add_view(bin_[o : o + bv["byteLength"]], bv)

    def add_view(self, data, like=None):
        bv = {k: v for k, v in (like or {}).items() if k in ("byteStride", "target", "name")}
        pad = (-self.size) % 4
        self.chunks.append(b"\0" * pad)
        self.size += pad
        bv.update({"buffer": 0, "byteOffset": self.size, "byteLength": len(data)})
        self.chunks.append(data)
        self.size += len(data)
        self.js["bufferViews"].append(bv)
        return len(self.js["bufferViews"]) - 1

    def add_floats(self, arr, typ):
        arr = np.ascontiguousarray(arr, np.float32)
        acc = {"bufferView": self.add_view(arr.tobytes()), "componentType": 5126, "count": len(arr), "type": typ}
        if typ == "SCALAR":
            acc["min"], acc["max"] = [float(arr.min())], [float(arr.max())]
        self.js["accessors"].append(acc)
        return len(self.js["accessors"]) - 1

    def write(self, path):
        self.js["buffers"] = [{"byteLength": self.size}]
        jb = json.dumps(self.js, separators=(",", ":")).encode()
        jb += b" " * ((-len(jb)) % 4)
        bb = b"".join(self.chunks)
        bb += b"\0" * ((-len(bb)) % 4)
        total = 12 + 8 + len(jb) + 8 + len(bb)
        with open(path, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, total))
            f.write(struct.pack("<II", len(jb), 0x4E4F534A) + jb)
            f.write(struct.pack("<II", len(bb), 0x004E4942) + bb)


def node_rot(n):
    return np.array(n.get("rotation", [0.0, 0.0, 0.0, 1.0]))


def add_clips(out, path, rename, base_names, base_parent):
    js, bin_ = load(path)
    names = [n.get("name") for n in js["nodes"]]
    have = {a["name"] for a in out.js.get("animations", [])}
    anims = js.get("animations", [])
    # (a joint's keys are local to its keyed parent: only children of the unkeyed armature change frame)
    joints = {i for sk in js.get("skins", []) for i in sk["joints"]}
    for a in anims:
        nm = rename if rename and len(anims) == 1 else a["name"]
        if nm in have:
            continue
        chans, samps = [], []
        for c in a["channels"]:
            node = c["target"]["node"]
            if names[node] not in base_names:
                continue
            s = a["samplers"][c["sampler"]]
            t = floats(js, bin_, s["input"])
            v = floats(js, bin_, s["output"])
            par = base_parent.get(base_names[names[node]])
            src_par = next((i for i, n in enumerate(js["nodes"]) if node in n.get("children", [])), None)
            if par is not None and src_par is not None and src_par not in joints:
                # base armature^-1 * this file's armature, onto the child's keys: same pose in the world
                rel = qmul(node_rot(out.js["nodes"][par]) * [-1, -1, -1, 1], node_rot(js["nodes"][src_par])[None])[0]
                if not np.allclose(rel, [0, 0, 0, 1], atol=1e-4):
                    if c["target"]["path"] == "translation":
                        v = qrot(rel, v)
                    elif c["target"]["path"] == "rotation":
                        v = qmul(rel, v)
            samps.append(
                {
                    "input": out.add_floats(t, "SCALAR"),
                    "output": out.add_floats(v, js["accessors"][s["output"]]["type"]),
                    "interpolation": s.get("interpolation", "LINEAR"),
                }
            )
            chans.append(
                {"sampler": len(samps) - 1, "target": {"node": base_names[names[node]], "path": c["target"]["path"]}}
            )
        out.js.setdefault("animations", []).append({"name": nm, "channels": chans, "samplers": samps})
        have.add(nm)


def in_place(out, clip, hips):
    for a in out.js.get("animations", []):
        if a["name"] != clip:
            continue
        for c in a["channels"]:
            if c["target"]["node"] != hips or c["target"]["path"] != "translation":
                continue
            s = a["samplers"][c["sampler"]]
            acc = out.js["accessors"][s["output"]]
            v = np.frombuffer(out.chunks[2 * acc["bufferView"] + 1], np.float32).reshape(-1, 3).copy()
            k = np.linspace(0.0, 1.0, len(v))[:, None]
            drift = (v[-1] - v[0]) * k
            drift[:, 1] = 0.0  # (the ground plane is X/Z: the bob stays)
            v -= drift
            out.chunks[2 * acc["bufferView"] + 1] = v.astype(np.float32).tobytes()


def colour_images(js):
    """Images used as a material's base colour."""
    out = set()
    for m in js.get("materials", []):
        t = m.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if t:
            out.add(js["textures"][t["index"]]["source"])
    return out


def shrink_textures(out, max_px, max_maps):
    colour = colour_images(out.js)
    for ii, img in enumerate(out.js.get("images", [])):
        cap = max_px if ii in colour else max_maps
        vi = img["bufferView"]
        raw = out.chunks[2 * vi + 1]
        im = Image.open(io.BytesIO(raw))
        if max(im.size) <= cap:
            continue
        k = cap / max(im.size)
        im = im.resize((round(im.size[0] * k), round(im.size[1] * k)), Image.LANCZOS)
        buf = io.BytesIO()
        if img.get("mimeType") == "image/png":
            im.save(buf, "PNG", optimize=True)
        else:
            im.convert("RGB").save(buf, "JPEG", quality=90)
        out.chunks[2 * vi + 1] = buf.getvalue()
    # (the views moved: lay them out again)
    data = [out.chunks[2 * i + 1] for i in range(len(out.js["bufferViews"]))]
    views = out.js["bufferViews"]
    out.js["bufferViews"], out.chunks, out.size = [], [], 0
    for d, bv in zip(data, views):
        out.add_view(d, bv)


def main(args):
    opts = {a.split("=", 1)[0]: a.split("=", 1)[1] for a in args if a.startswith("--")}
    files = [a for a in args if not a.startswith("--")]
    out = Out(*load(files[1]))
    base_names = {n.get("name"): i for i, n in enumerate(out.js["nodes"])}
    base_parent = {ch: i for i, n in enumerate(out.js["nodes"]) for ch in n.get("children", [])}
    for f in files[2:]:
        path, _, rename = f.partition("=")
        add_clips(out, path, rename, base_names, base_parent)
    for clip in filter(None, opts.get("--in-place", "").split(",")):
        in_place(out, clip, base_names["Hips"])
    shrink_textures(out, int(opts.get("--max-tex", "2048")), int(opts.get("--max-tex-maps", "1024")))
    out.write(files[0])
    print(files[0], [a["name"] for a in out.js.get("animations", [])], f"{out.size / 1e6:.1f} MB bin")


if __name__ == "__main__":
    main(sys.argv[1:])
