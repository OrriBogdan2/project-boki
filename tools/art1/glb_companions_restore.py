#!/usr/bin/env python3
"""Puts Meeko's full-resolution sun and raincloud (the live design, from the contract art/wardens/pip/pip.glb) back
into the Meshy-native body glb, over the decimated copies the native switch (e0c5e67730) left there.

Why: the native decimation cut the companions to about a quarter (sun 480 -> 124 tris: a faceted block; faces 32/34 ->
8/9 tris that sink into the curved body) and baked the calm cell into the face decals' UVs (whole-atlas coordinates),
while shaders/warden_mood_atlas.gdshader wants UV 0..1 over one cell: the game drew a magnified corner of an eye, a
black jagged patch. Same design, same materials, same atlas; only geometry and UVs are restored.

Per companion group (sun: cloth-sun + eyes-mood_sun; cloud: skin-cloud + ice-drop + eyes-mood_cloud) one similarity
transform (rotation, uniform scale, offset) is fitted from the contract body surface onto the native one (ICP, start
from a turn of 180 deg about Y: the native model faces the other way), then every surface of the group is re-written
with the contract's vertices, normals, UVs and triangles, skinned rigidly to the bone the native copy rode. Everything
else (body, wings, skin, clips, textures) stays byte-identical in the JSON; new data is appended to the BIN chunk.

  python3 tools/art1/glb_companions_restore.py NATIVE.glb CONTRACT.glb OUT.glb
"""
import json
import struct
import sys

import numpy as np

GROUPS = {"sun": ["cloth-sun", "eyes-mood_sun"], "cloud": ["skin-cloud", "ice-drop", "eyes-mood_cloud"]}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
DT = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}


def load(path):
    f = open(path, "rb").read()
    n = struct.unpack("<I", f[12:16])[0]
    j = json.loads(f[20:20 + n])
    b0 = 20 + n
    bl = struct.unpack("<I", f[b0:b0 + 4])[0]
    return j, bytearray(f[b0 + 8:b0 + 8 + bl])


def acc(j, b, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    nc = NCOMP[a["type"]]
    o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    x = np.frombuffer(bytes(b), DT[a["componentType"]], a["count"] * nc, o)
    return x.reshape(a["count"], nc) if nc > 1 else x


def prims(j):
    out = {}
    for me in j["meshes"]:
        for p in me["primitives"]:
            out[j["materials"][p["material"]]["name"]] = p
    return out


def umeyama(src, dst):
    ms, md = src.mean(0), dst.mean(0)
    s0, d0 = src - ms, dst - md
    u, sv, vt = np.linalg.svd(d0.T @ s0 / len(src))
    d = np.eye(3)
    if np.linalg.det(u @ vt) < 0:
        d[2, 2] = -1
    r = u @ d @ vt
    s = np.trace(np.diag(sv) @ d) / (s0 ** 2).sum(1).mean()
    return r, s, md - s * r @ ms


def fit(src, dst):
    """Similarity src -> dst (dst = decimated copy of src's surface): ICP, nearest src point for every dst point."""
    r = np.diag([-1.0, 1.0, -1.0])
    s = np.cbrt(np.prod(np.ptp(dst, 0)) / np.prod(np.ptp(src, 0)))
    t = dst.mean(0) - s * r @ src.mean(0)
    for _ in range(60):
        cur = (s * (r @ src.T)).T + t
        nn = np.argmin(((dst[:, None, :] - cur[None, :, :]) ** 2).sum(2), 1)
        r, s, t = umeyama(src[nn], dst)
    cur = (s * (r @ src.T)).T + t
    err = np.sqrt(((dst[:, None, :] - cur[None, :, :]) ** 2).sum(2).min(1))
    return r, s, t, err


def main(native, contract, out):
    j, b = load(native)
    cj, cb = load(contract)
    np_, cp = prims(j), prims(cj)

    def put(arr, ctype, typ, target=None, minmax=False):
        nonlocal b
        while len(b) % 4:
            b.append(0)
        raw = np.ascontiguousarray(arr.astype(DT[ctype])).tobytes()
        bv = {"buffer": 0, "byteOffset": len(b), "byteLength": len(raw)}
        if target:
            bv["target"] = target
        b += raw
        j["bufferViews"].append(bv)
        a = {"bufferView": len(j["bufferViews"]) - 1, "componentType": ctype, "count": len(arr), "type": typ}
        if minmax:
            a["min"] = [float(v) for v in arr.min(0)]
            a["max"] = [float(v) for v in arr.max(0)]
        j["accessors"].append(a)
        return len(j["accessors"]) - 1

    for gid, mats in GROUPS.items():
        body = mats[0]
        src = acc(cj, cb, cp[body]["attributes"]["POSITION"]).astype(np.float64)
        dst = acc(j, b, np_[body]["attributes"]["POSITION"]).astype(np.float64)
        r, s, t, err = fit(src, dst)
        print(f"{gid}: scale {s:.4f} fit err mean {err.mean()*100:.2f} cm max {err.max()*100:.2f} cm")
        for m in mats:
            p, q = np_[m], cp[m]
            a = p["attributes"]
            joint = int(acc(j, b, a["JOINTS_0"])[0, 0])
            c0 = acc(j, b, a["COLOR_0"])[0]
            c1 = acc(j, b, a["COLOR_1"])[0]
            P = (s * (r @ acc(cj, cb, q["attributes"]["POSITION"]).astype(np.float64).T)).T + t
            N = (r @ acc(cj, cb, q["attributes"]["NORMAL"]).astype(np.float64).T).T
            N /= np.linalg.norm(N, axis=1, keepdims=True) + 1e-12
            uv = acc(cj, cb, q["attributes"]["TEXCOORD_0"])
            idx = acc(cj, cb, q["indices"]).astype(np.uint32)
            nv = len(P)
            J = np.zeros((nv, 4), np.uint16)
            J[:, 0] = joint
            W = np.zeros((nv, 4), np.float32)
            W[:, 0] = 1
            a["POSITION"] = put(P, 5126, "VEC3", 34962, True)
            a["NORMAL"] = put(N, 5126, "VEC3", 34962)
            a["TEXCOORD_0"] = put(uv, 5126, "VEC2", 34962)
            a["COLOR_0"] = put(np.tile(c0, (nv, 1)), 5126, "VEC4", 34962)
            a["COLOR_1"] = put(np.tile(c1, (nv, 1)), 5126, "VEC4", 34962)
            a["JOINTS_0"] = put(J, 5123, "VEC4", 34962)
            a["WEIGHTS_0"] = put(W, 5126, "VEC4", 34962)
            p["indices"] = put(idx, 5125 if nv > 65535 else 5123, "SCALAR", 34963)
            p.pop("targets", None)
            print(f"  {m}: {len(acc(j, b, q['indices'])) if False else len(idx)//3} tris, {nv} verts, bone {joint},"
                  f" uv {uv.min(0).round(3)}..{uv.max(0).round(3)}")
    j["buffers"][0]["byteLength"] = len(b)
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    while len(b) % 4:
        b.append(0)
    total = 12 + 8 + len(js) + 8 + len(b)
    with open(out, "wb") as fo:
        fo.write(struct.pack("<III", 0x46546C67, 2, total))
        fo.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        fo.write(struct.pack("<II", len(b), 0x004E4942) + bytes(b))


if __name__ == "__main__":
    main(*sys.argv[1:4])
