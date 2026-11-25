"""Grimble (dredge) native model, round 29 (plan: gens/hunter-round-1124/grimble/PLAN-1124o.md section 12).

  dredge_r29.py --goo OUT IN MESHY.glb [--width M] [--keep-horns] [--top Y]

The goo arm is the weakest region (art-gate 4.0: "thin tube, detached from the shoulder, loose claws, torn end"; the
turnaround's goo arm is a thick twisted mass with drips and cream horns, as wide as the torso). A Meshy goo arm
(image-to-3D of an isolated turnaround crop, gens/hunter-round-1124/grimble/r29) replaces the goo primitive:

  - fit: the Meshy arm's height runs along the old goo's centreline (slab centroids, shoulder top -> tail tip); each
    vertex keeps its offset from the Meshy arm's own per-height centre, turned into the centreline's frame and scaled
    so the goo body is --width wide (default 0.30 m, the turnaround's arm vs torso). Its top blob sits over the socket.
  - weights: each new vertex takes the mean dense weights of the 6 nearest old goo vertices (the r12-r28 GooTail chain,
    RightArm / RightForeArm), so it follows every clip as the old goo did.
  - texture: the Meshy base colour (2048 px JPEG) goes in place of the goo image (only the goo material uses it);
    material skin-goo keeps its name (warden_look's desat / no_ink lines still apply).
  - horns: the old leather-horn prims are dropped when the Meshy arm carries its own horns (--keep-horns keeps them).
Every other primitive, the skin, bones and clips are untouched. numpy + scipy + PIL.
"""

import argparse
import io
import json
import os
import struct
import sys

import numpy as np
from PIL import Image
from scipy.spatial import cKDTree

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art1"))
import glb_relax as g  # noqa: E402
from glb_add_clips import write  # noqa: E402
from sable_wings import compact  # noqa: E402

GOO = 6  # primitive index of the goo arm (material skin-goo)
GOO_ALPHA = 0.5  # the goo's COLOR_0 alpha (constant on the old goo)
NEAR = 6


def load(path):
    d = open(path, "rb").read()
    n = struct.unpack("<I", d[12:16])[0]
    js = json.loads(d[20 : 20 + n])
    m = struct.unpack("<I", d[20 + n : 24 + n])[0]
    return js, bytearray(d[28 + n : 28 + n + m])


NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
CTYPE = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}


def acc(js, b, i):
    """Accessor i as an array [count, n] (strided views read in one go; glb_relax.accessor has no VEC2)."""
    a = js["accessors"][i]
    v = js["bufferViews"][a["bufferView"]]
    n, dt = NCOMP[a["type"]], np.dtype(CTYPE[a["componentType"]])
    start = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = v.get("byteStride", n * dt.itemsize)
    raw = np.frombuffer(bytes(b[start : start + stride * (a["count"] - 1) + n * dt.itemsize]), np.uint8)
    raw = np.pad(raw, (0, stride * a["count"] - len(raw))).reshape(a["count"], stride)
    out = raw[:, : n * dt.itemsize].copy().view(dt).reshape(a["count"], n)
    if a.get("normalized"):
        out = out.astype(float) / np.iinfo(dt).max
    return out


def node_matrices(js):
    out = {}

    def walk(i, parent):
        nd = js["nodes"][i]
        m = parent @ (np.array(nd["matrix"]).reshape(4, 4).T if "matrix" in nd else g.local_matrix(
            {"rotation": nd.get("rotation", [0, 0, 0, 1]), "scale": nd.get("scale", [1, 1, 1]),
             "translation": nd.get("translation", [0, 0, 0])}))
        out[i] = m
        for c in js["nodes"][i].get("children", []):
            walk(c, m)

    for s in js["scenes"][js.get("scene", 0)]["nodes"]:
        walk(s, np.eye(4))
    return out


def meshy_part(path):
    """World-space verts, uvs, tris and base colour image (PIL) of a Meshy image-to-3D glb (one textured mesh)."""
    js, b = load(path)
    mats = node_matrices(js)
    P, UV, F, img = [], [], [], None
    for ni, nd in enumerate(js["nodes"]):
        if "mesh" not in nd:
            continue
        for pr in js["meshes"][nd["mesh"]]["primitives"]:
            p = acc(js, b, pr["attributes"]["POSITION"]).astype(float)
            p = (np.c_[p, np.ones(len(p))] @ mats[ni].T)[:, :3]
            F.append(acc(js, b, pr["indices"]).reshape(-1, 3) + sum(len(q) for q in P))
            P.append(p)
            UV.append(acc(js, b, pr["attributes"]["TEXCOORD_0"]).astype(float))
            t = js["materials"][pr["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
            im = js["images"][js["textures"][t]["source"]]
            v = js["bufferViews"][im["bufferView"]]
            img = Image.open(io.BytesIO(bytes(b[v.get("byteOffset", 0) : v.get("byteOffset", 0) + v["byteLength"]])))
    return np.concatenate(P), np.concatenate(UV), np.concatenate(F), img.convert("RGB")


def centreline(P, top):
    """Old goo centreline from `top` down to its tip: slab centroids every 5 cm, smoothed, as an arc-length polyline."""
    ys = np.arange(min(top, P[:, 1].max()), P[:, 1].min() + 0.02, -0.05)
    pts = []
    for y in ys:
        m = np.abs(P[:, 1] - y) < 0.04
        if m.sum() > 20:
            q = np.median(P[m], 0)
            pts.append([q[0], y, q[2]])
    c = np.array(pts)
    for _ in range(3):
        c[1:-1] = 0.25 * c[:-2] + 0.5 * c[1:-1] + 0.25 * c[2:]
    if top > c[0, 1]:
        c = np.vstack([[c[0, 0], top, c[0, 2]], c])
    s = np.r_[0, np.cumsum(np.linalg.norm(np.diff(c, axis=0), axis=1))]
    return c, s


def rot_to(a, b):
    """Rotation matrix turning unit a onto unit b (minimal)."""
    v, c = np.cross(a, b), float(np.dot(a, b))
    if c < -0.9999:
        return np.diag([1.0, -1.0, -1.0])
    k = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + k + k @ k / (1 + c)


def fit(MP, cl, s, width, horn_side, cream):
    """Bend the Meshy arm (vertical, top = max y) along the centreline cl (arc lengths s). Offsets are taken from the
    arm's own per-height centre (goo vertices only, smoothed), so its S-bend is straightened onto the old goo path and
    the top blob lands on the shoulder; lateral scale = width / the goo body's median width (horns excluded)."""
    top, bot = MP[:, 1].max(), MP[:, 1].min()
    H = top - bot
    L = s[-1]
    hf = (top - MP[:, 1]) / H
    bins = np.linspace(0, 1, 41)
    cen, wid = [], []
    for a, z in zip(bins[:-1], bins[1:]):
        m = (hf >= a) & (hf <= z) & ~cream
        m = m if m.sum() > 20 else (hf >= a) & (hf <= z)
        cen.append(np.median(MP[m][:, [0, 2]], 0))
        wid.append(np.percentile(MP[m, 0], 90) - np.percentile(MP[m, 0], 10))
    cen = np.array(cen)
    for _ in range(4):
        cen[1:-1] = 0.25 * cen[:-2] + 0.5 * cen[1:-1] + 0.25 * cen[2:]
    mid = 0.5 * (bins[:-1] + bins[1:])
    cx, cz = np.interp(hf, mid, cen[:, 0]), np.interp(hf, mid, cen[:, 1])
    k = width / float(np.median(wid))
    off = np.c_[MP[:, 0] - cx, np.zeros(len(MP)), MP[:, 2] - cz]
    # horns (cream) outward: the Meshy arm's horn side must face away from the body (-x, the goo side)
    if horn_side > 0:
        off[:, [0, 2]] *= -1  # half turn about y (no mirror: winding kept)
    h = hf * L
    T = np.gradient(cl, s, axis=0)
    T /= np.linalg.norm(T, axis=1, keepdims=True)
    seg = np.clip(np.searchsorted(s, h) - 1, 0, len(s) - 2)
    f = ((h - s[seg]) / (s[seg + 1] - s[seg]))[:, None]
    base = cl[seg] * (1 - f) + cl[seg + 1] * f
    tan = T[seg] * (1 - f) + T[seg + 1] * f
    tan /= np.linalg.norm(tan, axis=1, keepdims=True)
    out = np.empty_like(MP)
    down = np.array([0.0, -1.0, 0.0])
    for i in range(len(MP)):
        out[i] = base[i] + rot_to(down, tan[i]) @ (k * off[i])
    return out, k


def vnormals(P, F):
    n = np.zeros_like(P)
    fn = np.cross(P[F[:, 1]] - P[F[:, 0]], P[F[:, 2]] - P[F[:, 0]])
    for c in range(3):
        np.add.at(n, F[:, c], fn)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


def add_view(js, b, arr, target=None):
    b += b"\0" * (-len(b) % 4)
    raw = arr.tobytes()
    v = {"buffer": 0, "byteOffset": len(b), "byteLength": len(raw)}
    if target:
        v["target"] = target
    js["bufferViews"].append(v)
    b += raw
    return len(js["bufferViews"]) - 1


def add_acc(js, b, arr, ctype, typ, target=None, minmax=False):
    a = {"bufferView": add_view(js, b, arr, target), "componentType": ctype, "count": len(arr), "type": typ}
    if minmax:
        a["min"], a["max"] = arr.min(0).tolist(), arr.max(0).tolist()
    js["accessors"].append(a)
    return len(js["accessors"]) - 1


def horn_side(MP, UV, img):
    """(+1 if the Meshy arm's cream (horn) vertices sit on its +x side else -1, cream vertex mask)."""
    px = np.asarray(img.resize((512, 512))).astype(float) / 255
    u = np.clip((UV[:, 0] % 1) * 511, 0, 511).astype(int)
    v = np.clip((UV[:, 1] % 1) * 511, 0, 511).astype(int)
    c = px[v, u]
    cream = (c.min(1) > 0.55) & (c.max(1) - c.min(1) < 0.3)
    ax = np.median(MP, 0)
    print("meshy part: %d verts, cream (horn) verts %d, their mean x-offset %.3f" % (
        len(MP), cream.sum(), (MP[cream, 0] - ax[0]).mean() if cream.any() else 0))
    return (1 if cream.any() and (MP[cream, 0] - ax[0]).mean() > 0 else -1), cream


def goo(o):
    js, b = load(o.inp)
    prims = js["meshes"][0]["primitives"]
    pr = prims[GOO]
    assert js["materials"][pr["material"]]["name"] == "skin-goo"
    P = acc(js, b, pr["attributes"]["POSITION"]).astype(float)
    J = acc(js, b, pr["attributes"]["JOINTS_0"]).astype(int)
    W = acc(js, b, pr["attributes"]["WEIGHTS_0"]).astype(float)
    nb = len(js["skins"][0]["joints"])
    dense = np.zeros((len(P), nb))
    np.add.at(dense, (np.repeat(np.arange(len(P)), 4), J.ravel()), W.ravel())

    MP, UV, F, img = meshy_part(o.meshy)
    side, cream = horn_side(MP, UV, img)
    cl, s = centreline(P, o.top)
    # the thicker goo would brush the goo-side thigh in run: its path moves out (-x) by --push below the shoulder
    cl[:, 0] -= o.push * np.clip((1.45 - cl[:, 1]) / 0.25, 0, 1)
    s = np.r_[0, np.cumsum(np.linalg.norm(np.diff(cl, axis=0), axis=1))]
    NP, k = fit(MP, cl, s, o.width, side, cream)
    print("centreline %d pts, length %.2f m, top %s tip %s; lateral scale %.3f" % (
        len(cl), s[-1], np.round(cl[0], 2), np.round(cl[-1], 2), k))
    for y in np.arange(1.6, 0.3, -0.2):
        m = np.abs(NP[:, 1] - y) < 0.04
        if m.any():
            print("  new goo y%.1f: wx %.2f wz %.2f (old wx %.2f)" % (
                y, np.ptp(NP[m, 0]), np.ptp(NP[m, 2]), np.ptp(P[np.abs(P[:, 1] - y) < 0.04, 0])))

    d, idx = cKDTree(P).query(NP, NEAR)
    wgt = 1.0 / np.maximum(d, 1e-3)
    nd = (dense[idx] * wgt[..., None]).sum(1) / wgt.sum(1, keepdims=True)
    top4 = np.argsort(-nd, axis=1)[:, :4]
    tw = np.take_along_axis(nd, top4, 1)
    tw /= tw.sum(1, keepdims=True)

    N = vnormals(NP, F)
    col = np.tile([1.0, 1.0, 1.0, GOO_ALPHA], (len(NP), 1))
    attrs = {
        "POSITION": add_acc(js, b, NP.astype(np.float32), 5126, "VEC3", 34962, True),
        "NORMAL": add_acc(js, b, N.astype(np.float32), 5126, "VEC3", 34962),
        "TEXCOORD_0": add_acc(js, b, UV.astype(np.float32), 5126, "VEC2", 34962),
        "WEIGHTS_0": add_acc(js, b, tw.astype(np.float32), 5126, "VEC4", 34962),
        "COLOR_0": add_acc(js, b, col.astype(np.float32), 5126, "VEC4", 34962),
        "JOINTS_0": add_acc(js, b, top4.astype(np.uint16), 5123, "VEC4", 34962),
    }
    pr["attributes"] = attrs
    pr["indices"] = add_acc(js, b, F.astype(np.uint32).ravel(), 5125, "SCALAR", 34963)

    tex = js["textures"][js["materials"][pr["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]]
    users = [m for m in js["materials"] if m.get("pbrMetallicRoughness", {}).get("baseColorTexture", {}).get("index")
             == js["materials"][pr["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]]
    assert len(users) == 1, "goo texture shared"
    jb = io.BytesIO()
    im = img.resize((2048, 2048), Image.LANCZOS) if img.size[0] > 2048 else img
    im.save(jb, "JPEG", quality=90)
    js["images"][tex["source"]]["bufferView"] = add_view(js, b, np.frombuffer(jb.getvalue(), np.uint8))
    js["images"][tex["source"]]["mimeType"] = "image/jpeg"

    if cream.sum() > 200 and not o.keep_horns:
        horns = [i for i, p in enumerate(prims) if js["materials"][p["material"]]["name"] == "leather-horn"]
        js["meshes"][0]["primitives"] = [p for i, p in enumerate(prims) if i not in horns]
        print("dropped %d old horn prims (the Meshy arm has its own horns)" % len(horns))
    b = compact(js, b)
    write(o.out, js, b)
    print("wrote %s: goo %d verts %d tris (was %d verts)" % (o.out, len(NP), len(F), len(P)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--goo", action="store_true")
    ap.add_argument("out")
    ap.add_argument("inp")
    ap.add_argument("meshy")
    ap.add_argument("--width", type=float, default=0.30, help="goo body width (m, horns excluded)")
    ap.add_argument("--top", type=float, default=1.70)
    ap.add_argument("--push", type=float, default=0.0, help="m: lower goo path moved out from the thigh (0.04/0.07 tried: clips got worse)")
    ap.add_argument("--keep-horns", action="store_true")
    o = ap.parse_args()
    goo(o)


if __name__ == "__main__":
    main()
