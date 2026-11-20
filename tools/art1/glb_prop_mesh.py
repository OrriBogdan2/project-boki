"""Swaps an unskinned prop mesh in a game .glb (Tarek's `eye_stone`, shared by his three orbiting stones) for a Meshy
prop's own mesh, UVs and paint, with no Blender. Rig, clips, nodes and every other mesh stay byte for byte.
  - the new mesh fills the old one's box (its longest side) about the old centre, so each stone node keeps its orbit
    and scale;
  - its glowing faces (the eye: texels of --glow-hue, saturated and bright) turn to where the old glow faces pointed
    and go on `glow-<tag>` (the toon's glow slot), the rest on `<slot>-<tag>`: one new image (--tex px JPEG) for both.
Run: python3 tools/art1/glb_prop_mesh.py IN.glb OUT.glb MESH SRC.glb [--slot leather] [--tag rock] [--tex 512]
     [--glow-hue 140,195] [--image v95_rock]"""
import argparse
import colorsys
import io
import json
import os
import struct
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import glb_add_clips as G  # noqa: E402

TYPES = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
DT = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}


def acc(j, b, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    n = TYPES[a["type"]]
    dt = np.dtype(DT[a["componentType"]])
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", n * dt.itemsize)
    raw = np.frombuffer(bytes(b[off:off + stride * (a["count"] - 1) + n * dt.itemsize]), np.uint8)
    out = np.lib.stride_tricks.as_strided(raw, (a["count"], n * dt.itemsize), (stride, 1)).copy()
    return out.view(dt).reshape(a["count"], n)


def node_matrix(nd):
    if "matrix" in nd:
        return np.array(nd["matrix"]).reshape(4, 4).T
    t = nd.get("translation", [0, 0, 0])
    x, y, z, w = nd.get("rotation", [0, 0, 0, 1])
    s = nd.get("scale", [1, 1, 1])
    r = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                  [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                  [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
    m = np.eye(4)
    m[:3, :3] = r * s
    m[:3, 3] = t
    return m


def world(j):
    """Each mesh node's world matrix (a Meshy export nests its mesh under a turned root)."""
    out, kids = {}, {c for nd in j["nodes"] for c in nd.get("children", [])}

    def walk(i, m):
        m = m @ node_matrix(j["nodes"][i])
        out[i] = m
        for c in j["nodes"][i].get("children", []):
            walk(c, m)
    for i in range(len(j["nodes"])):
        if i not in kids:
            walk(i, np.eye(4))
    return out


def source(path, hue):
    """The prop's triangles in one list: positions and normals in its world frame, UVs, a glow flag per triangle and
    its base-colour image."""
    j, b = G.read(path)
    P, N, U, I, img = [], [], [], [], None
    for ni, m in world(j).items():
        nd = j["nodes"][ni]
        if "mesh" not in nd:
            continue
        for pr in j["meshes"][nd["mesh"]]["primitives"]:
            at = pr["attributes"]
            p = acc(j, b, at["POSITION"]).astype(np.float64)
            n = acc(j, b, at["NORMAL"]).astype(np.float64) if "NORMAL" in at else np.zeros_like(p)
            I.append(acc(j, b, pr["indices"]).reshape(-1, 3).astype(np.int64) + sum(len(x) for x in P))
            P.append(p @ m[:3, :3].T + m[:3, 3])
            nn = n @ np.linalg.inv(m[:3, :3])
            N.append(nn / np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-9))
            U.append(acc(j, b, at["TEXCOORD_0"]).astype(np.float64))
            if img is None:
                t = j["materials"][pr["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
                bv = j["bufferViews"][j["images"][j["textures"][t]["source"]]["bufferView"]]
                o = bv.get("byteOffset", 0)
                img = Image.open(io.BytesIO(bytes(b[o:o + bv["byteLength"]]))).convert("RGB")
    P, N, U, I = np.concatenate(P), np.concatenate(N), np.concatenate(U), np.concatenate(I)
    a = np.asarray(img).astype(np.float64) / 255
    h, w = a.shape[:2]
    c = U[I].mean(1)
    rgb = a[(c[:, 1] * h).astype(int) % h, (c[:, 0] * w).astype(int) % w]
    hsv = np.array([colorsys.rgb_to_hsv(*x) for x in rgb])
    glow = (hsv[:, 0] * 360 >= hue[0]) & (hsv[:, 0] * 360 <= hue[1]) & (hsv[:, 1] > 0.3) & (hsv[:, 2] > 0.45)
    return P, N, U, I, glow, img


def turn(a, b):
    """The rotation taking unit vector a onto unit vector b."""
    v, c = np.cross(a, b), float(np.dot(a, b))
    if c < -0.9999:
        ax = np.cross(a, [1, 0, 0] if abs(a[0]) < 0.9 else [0, 1, 0])
        ax /= np.linalg.norm(ax)
        return 2 * np.outer(ax, ax) - np.eye(3)
    k = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + k + k @ k / (1 + c)


def add_view(j, b, data, target=None):
    b.extend(b"\0" * (-len(b) % 4))
    bv = {"buffer": 0, "byteOffset": len(b), "byteLength": len(data)}
    if target:
        bv["target"] = target
    b.extend(data)
    j["bufferViews"].append(bv)
    return len(j["bufferViews"]) - 1


def add_acc(j, b, arr, kind, ctype, target):
    arr = np.ascontiguousarray(arr, DT[ctype])
    a = {"bufferView": add_view(j, b, arr.tobytes(), target), "componentType": ctype, "count": len(arr), "type": kind}
    if kind == "VEC3":
        a["min"], a["max"] = arr.min(0).tolist(), arr.max(0).tolist()
    j["accessors"].append(a)
    return len(j["accessors"]) - 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("inp")
    ap.add_argument("out")
    ap.add_argument("mesh")
    ap.add_argument("src")
    ap.add_argument("--slot", default="leather")
    ap.add_argument("--tag", default="rock")
    ap.add_argument("--tex", type=int, default=512)
    ap.add_argument("--glow-hue", default="140,195")
    ap.add_argument("--image", help="the new image's name (default MESH_TAG; Godot extracts it as <glb>_<name>.jpg, and"
                    " v95_to_game's texture_imports VRAM-compresses only <art>_v95*: e.g. v95_rock)")
    o = ap.parse_args()
    j, b = G.read(o.inp)
    mi = next(i for i, m in enumerate(j["meshes"]) if m["name"] == o.mesh)
    old = j["meshes"][mi]["primitives"]
    old_tris = sum(j["accessors"][pr["indices"]]["count"] // 3 for pr in old)
    op = np.concatenate([acc(j, b, pr["attributes"]["POSITION"]) for pr in old]).astype(np.float64)
    lo, hi = op.min(0), op.max(0)
    centre, size = (lo + hi) / 2, float((hi - lo).max())
    glow_mats = {i for i, m in enumerate(j["materials"]) if m.get("name", "").startswith("glow")}
    eye_old = np.concatenate([acc(j, b, pr["attributes"]["POSITION"]) for pr in old if pr.get("material") in glow_mats])
    d_old = eye_old.mean(0) - centre
    d_old /= np.linalg.norm(d_old)

    P, N, U, I, glow, img = source(o.src, [float(x) for x in o.glow_hue.split(",")])
    assert glow.any() and not glow.all(), "no glow faces found: check --glow-hue"
    plo, phi = P.min(0), P.max(0)
    pc = (plo + phi) / 2
    d_new = P[I[glow]].reshape(-1, 3).mean(0) - pc
    d_new /= np.linalg.norm(d_new)
    R = turn(d_new, d_old)
    s = size / float((phi - plo).max())
    P2 = (P - pc) @ R.T * s + centre
    N2 = N @ R.T

    im = img.resize((o.tex, o.tex), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=90)
    j["images"].append({"name": o.image or "%s_%s" % (o.mesh, o.tag), "mimeType": "image/jpeg",
                        "bufferView": add_view(j, b, buf.getvalue())})
    tex = {"source": len(j["images"]) - 1}
    if j.get("samplers"):
        tex["sampler"] = 0
    j["textures"].append(tex)
    t_i = len(j["textures"]) - 1
    mats = []
    for slot in (o.slot, "glow"):
        j["materials"].append({"name": "%s-%s" % (slot, o.tag), "pbrMetallicRoughness": {
            "baseColorTexture": {"index": t_i}, "metallicFactor": 0.0, "roughnessFactor": 1.0}})
        mats.append(len(j["materials"]) - 1)
    pa = add_acc(j, b, P2, "VEC3", 5126, 34962)
    na = add_acc(j, b, N2, "VEC3", 5126, 34962)
    ua = add_acc(j, b, U, "VEC2", 5126, 34962)
    prims = []
    for flag, mat in ((False, mats[0]), (True, mats[1])):
        ia = add_acc(j, b, I[glow == flag].reshape(-1), "SCALAR", 5125, 34963)
        prims.append({"attributes": {"POSITION": pa, "NORMAL": na, "TEXCOORD_0": ua}, "indices": ia, "material": mat})
    j["meshes"][mi]["primitives"] = prims
    b = G.prune(j, b)
    G.write(o.out, j, b)
    print("glb_prop_mesh: %s %d tris (%d glow) -> box %.3f, eye %s, image %dpx; old %d tris" % (
        o.mesh, len(I), int(glow.sum()), size, np.round(d_old, 2).tolist(), o.tex, old_tris))


if __name__ == "__main__":
    main()
