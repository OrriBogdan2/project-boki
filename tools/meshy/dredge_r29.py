"""Grimble (dredge) native model, round 29 (plan: gens/hunter-round-1124/grimble/PLAN-1124o.md section 12).

  dredge_r29.py --goo OUT IN MESHY.glb [--width M] [--keep-horns] [--bendy-horns] [--top Y]
                [--section] [--root-skin A,B] [--extend M] [--horn-prim]   (round 30, PLAN-1124o.md section 13)

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
  - the Meshy horns are rigid: each cream patch takes its root's weights (no bending / flattening in Attack).
  - horns: the old leather-horn prims are dropped when the Meshy arm carries its own horns (--keep-horns keeps them).
Round 30 (review of r29b: goo root torn in Attack, goo sheet over the thigh, goo short, horns flat lavender blades):
  - --section: weights by arc position, not per vertex: each new vertex takes the mean weights of the old goo's slab at
    its arc length (2 cm bins, smoothed), so a cross-section moves as one piece (r29b's nearest-vertex copy sheared the
    2x thicker section between RightArm / RightForeArm / GooTail: 54.8x stretch in Attack).
  - --root-skin A,B: goo within A m of the top takes the nearest shoulder skin's weights (skin-native, r28's relaxed
    shoulder), faded to the goo weights by B m: the root rides the shoulder instead of tearing off it.
  - --extend M: the centreline runs M m past the old tip (same tangent bent toward straight down); past the old tip the
    weights are the tip's. The turnaround's goo pools at the foot; r29b stopped at mid-thigh.
  - --horn-prim: the cream horn faces become their own primitive, material leather-horn (leather slot: ink shell, low
    desat) on the same texture, so they read as solid bone instead of skin-goo lavender.
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
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
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
        m = parent @ (
            np.array(nd["matrix"]).reshape(4, 4).T
            if "matrix" in nd
            else g.local_matrix(
                {
                    "rotation": nd.get("rotation", [0, 0, 0, 1]),
                    "scale": nd.get("scale", [1, 1, 1]),
                    "translation": nd.get("translation", [0, 0, 0]),
                }
            )
        )
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
    return out, k, h


def extend(cl, s, m):
    """The centreline continued m metres past its tip: the last tangent bent toward straight down, 2.5 cm steps."""
    t = cl[-1] - cl[-2]
    t /= np.linalg.norm(t)
    pts, p = [], cl[-1].copy()
    n = max(2, int(round(m / 0.025)))
    for i in range(n):
        f = (i + 1) / n
        d = (1 - f) * t + f * np.array([0.0, -1.0, 0.0])
        p = p + d / np.linalg.norm(d) * (m / n)
        pts.append(p.copy())
    c = np.vstack([cl, pts])
    return c, np.r_[0, np.cumsum(np.linalg.norm(np.diff(c, axis=0), axis=1))]


def section_weights(P, dense, cl, s, h):
    """Mean dense weights of the old goo's slab at each arc length h (old verts projected on the centreline, 2 cm
    bins, empty bins filled from neighbours, smoothed along the length)."""
    fine = np.linspace(0, s[-1], 400)
    pts = np.c_[[np.interp(fine, s, cl[:, i]) for i in range(3)]].T
    _, j = cKDTree(pts).query(P)
    ho = fine[j]
    bins = np.arange(0, s[-1] + 0.02, 0.02)
    bi = np.clip(np.digitize(ho, bins) - 1, 0, len(bins) - 1)
    acc_w = np.zeros((len(bins), dense.shape[1]))
    cnt = np.bincount(bi, minlength=len(bins)).astype(float)
    np.add.at(acc_w, bi, dense)
    have = cnt > 0
    acc_w[have] /= cnt[have, None]
    idx = np.arange(len(bins))
    for c in range(dense.shape[1]):
        acc_w[:, c] = np.interp(idx, idx[have], acc_w[have, c])
    for _ in range(3):
        acc_w[1:-1] = 0.25 * acc_w[:-2] + 0.5 * acc_w[1:-1] + 0.25 * acc_w[2:]
    mid = bins + 0.01
    out = np.stack([np.interp(h, mid, acc_w[:, c]) for c in range(dense.shape[1])], 1)
    out /= np.maximum(out.sum(1, keepdims=True), 1e-9)
    print("section weights: %d slabs over %.2f m (old goo projected)" % (have.sum(), s[-1]))
    return out


def root_skin(js, b, nb, NP, nd, h, a, z):
    """Goo within a m of arc from the top takes the mean weights of its 6 nearest skin-native vertices, faded back
    to nd by z m."""
    SP, SD = [], []
    for p in js["meshes"][0]["primitives"]:
        if js["materials"][p["material"]]["name"] != "skin-native":
            continue
        q = acc(js, b, p["attributes"]["POSITION"]).astype(float)
        J = acc(js, b, p["attributes"]["JOINTS_0"]).astype(int)
        W = acc(js, b, p["attributes"]["WEIGHTS_0"]).astype(float)
        dn = np.zeros((len(q), nb))
        np.add.at(dn, (np.repeat(np.arange(len(q)), J.shape[1]), J.ravel()), W.ravel())
        SP.append(q)
        SD.append(dn)
    SP, SD = np.concatenate(SP), np.concatenate(SD)
    f = np.clip((z - h) / (z - a), 0, 1)
    m = f > 0
    d, idx = cKDTree(SP).query(NP[m], NEAR)
    wgt = 1.0 / np.maximum(d, 1e-3)
    sk = (SD[idx] * wgt[..., None]).sum(1) / wgt.sum(1, keepdims=True)
    out = nd.copy()
    out[m] = f[m, None] * sk + (1 - f[m, None]) * nd[m]
    print(
        "root skin: %d goo verts blended to shoulder skin weights (full to %.2f m, none past %.2f m), mean skin dist %.3f m"
        % (m.sum(), a, z, d[:, 0].mean())
    )
    return out


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
    print(
        "meshy part: %d verts, cream (horn) verts %d, their mean x-offset %.3f"
        % (len(MP), cream.sum(), (MP[cream, 0] - ax[0]).mean() if cream.any() else 0)
    )
    return (1 if cream.any() and (MP[cream, 0] - ax[0]).mean() > 0 else -1), cream


def rigid_horns(NP, F, cream, nd):
    """Each horn (a connected cream patch, welded by position so UV-seam copies stay one piece) takes the mean weights
    of its root (its cream vertices that share a face with goo): it moves as one piece instead of bending and
    flattening with the goo in Attack (r28 did the same for the old horn prims)."""
    _, wi = np.unique(np.round(NP / 1e-4).astype(np.int64), axis=0, return_inverse=True)
    wi = wi.ravel()
    nw = wi.max() + 1
    wc = np.zeros(nw, bool)
    np.logical_or.at(wc, wi, cream)
    WF = wi[F]
    e = np.r_[WF[:, [0, 1]], WF[:, [1, 2]], WF[:, [2, 0]]]
    both = wc[e[:, 0]] & wc[e[:, 1]]
    ncomp, lab = connected_components(
        coo_matrix((np.ones(both.sum()), (e[both, 0], e[both, 1])), (nw, nw)), directed=False
    )
    mixed = wc[WF].any(1) & ~wc[WF].all(1)
    root = np.zeros(nw, bool)
    root[WF[mixed].ravel()] = True
    root &= wc
    ndw = np.zeros((nw, nd.shape[1]))
    np.add.at(ndw, wi, nd)
    ndw /= np.bincount(wi, minlength=nw)[:, None]
    done = 0
    for c in np.unique(lab[wc]):
        m = wc & (lab == c)
        r = m & root
        if m.sum() < 20 or not r.any():
            continue
        ndw[m] = ndw[r].mean(0)
        done += 1
    print("rigid horns: %d cream patches made rigid on their root weights" % done)
    return ndw[wi]


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
    s_old = s[-1]
    if o.extend > 0:
        cl, s = extend(cl, s, o.extend)
    NP, k, h = fit(MP, cl, s, o.width, side, cream)
    print(
        "centreline %d pts, length %.2f m, top %s tip %s; lateral scale %.3f"
        % (len(cl), s[-1], np.round(cl[0], 2), np.round(cl[-1], 2), k)
    )
    for y in np.arange(1.6, 0.3, -0.2):
        m = np.abs(NP[:, 1] - y) < 0.04
        if m.any():
            print(
                "  new goo y%.1f: wx %.2f wz %.2f (old wx %.2f)"
                % (y, np.ptp(NP[m, 0]), np.ptp(NP[m, 2]), np.ptp(P[np.abs(P[:, 1] - y) < 0.04, 0]))
            )

    d, idx = cKDTree(P).query(NP, NEAR)
    wgt = 1.0 / np.maximum(d, 1e-3)
    nd = (dense[idx] * wgt[..., None]).sum(1) / wgt.sum(1, keepdims=True)
    if o.section:
        nd = section_weights(P, dense, cl, s, np.minimum(h, s_old))
    if o.root_skin:
        a, z = (float(x) for x in o.root_skin.split(","))
        nd = root_skin(js, b, nb, NP, nd, h, a, z)
    if not o.bendy_horns:
        nd = rigid_horns(NP, F, cream, nd)
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
    hf = cream[F].all(1) if o.horn_prim else np.zeros(len(F), bool)
    pr["indices"] = add_acc(js, b, F[~hf].astype(np.uint32).ravel(), 5125, "SCALAR", 34963)
    horn_pr = None
    if hf.any():
        mat = json.loads(json.dumps(js["materials"][pr["material"]]))
        mat["name"] = "leather-horn"
        js["materials"].append(mat)
        horn_pr = {
            "attributes": dict(attrs),
            "material": len(js["materials"]) - 1,
            "indices": add_acc(js, b, F[hf].astype(np.uint32).ravel(), 5125, "SCALAR", 34963),
        }
        print("horn prim: %d of %d goo tris (leather-horn)" % (hf.sum(), len(F)))

    tex = js["textures"][js["materials"][pr["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]]
    users = [
        m
        for m in js["materials"]
        if m.get("pbrMetallicRoughness", {}).get("baseColorTexture", {}).get("index")
        == js["materials"][pr["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    ]
    assert len(users) == 1 + (horn_pr is not None), "goo texture shared"
    jb = io.BytesIO()
    im = img.resize((2048, 2048), Image.LANCZOS) if img.size[0] > 2048 else img
    im.save(jb, "JPEG", quality=90)
    js["images"][tex["source"]]["bufferView"] = add_view(js, b, np.frombuffer(jb.getvalue(), np.uint8))
    js["images"][tex["source"]]["mimeType"] = "image/jpeg"

    if cream.sum() > 200 and not o.keep_horns:
        horns = [i for i, p in enumerate(prims) if js["materials"][p["material"]]["name"] == "leather-horn"]
        js["meshes"][0]["primitives"] = [p for i, p in enumerate(prims) if i not in horns]
        print("dropped %d old horn prims (the Meshy arm has its own horns)" % len(horns))
    if horn_pr:
        js["meshes"][0]["primitives"].append(horn_pr)
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
    ap.add_argument(
        "--push",
        type=float,
        default=0.0,
        help="m: lower goo path moved out from the thigh (0.04/0.07 tried: clips got worse)",
    )
    ap.add_argument("--bendy-horns", action="store_true", help="horns keep the goo's per-vertex weights (r29a)")
    ap.add_argument("--keep-horns", action="store_true")
    ap.add_argument("--section", action="store_true", help="r30: weights by the old goo slab at the same arc length")
    ap.add_argument("--root-skin", default="", help="r30: A,B m: top goo takes the shoulder skin weights, faded by B")
    ap.add_argument("--extend", type=float, default=0.0, help="r30: m past the old goo tip")
    ap.add_argument("--horn-prim", action="store_true", help="r30: horns in their own leather-horn primitive")
    o = ap.parse_args()
    goo(o)


if __name__ == "__main__":
    main()
