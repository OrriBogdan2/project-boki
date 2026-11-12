"""Kael v2's clips: the hand-keyed clips of the first Kael (ext/art1-kael-2's rig, 67 bones; tools/art1/kael_clips.py)
copied onto the v2 model by bone name. The two rigs share every rest rotation of the bones they have in common, so each
rotation track copies as is. The v2 torso is longer and the shoulders wider, so a translation track keeps its motion
and takes the v2 rest as its base (new = old - old rest + new rest: the hips' bob rides the v2 hip height). Bones only
the first rig had (lids, brows, fingers, thumb, feet, the scarftail and centre-mane springs) are dropped, and springs
go untracked (the game's spring chains drive them from the rest pose).
A source with only some of the clips (kael_clips.py's `idle,stance` argument) replaces those and keeps the target's
others. The target gets the x_breath leaf (docs/art/IDLE_AUDIT.md): a bone under hips at the back of the rib cage,
with the Body's hips weights of the chest band moved onto it, so the idle's 3 % breath scale lifts the chest and
nothing else (listed in warden_anim kael.json "extra_bones").
Run with Blender's python (numpy):
  blender -b --factory-startup --python tools/art1/kael_retarget.py -- <old.glb> <v2.glb> <out.glb>"""
import os
import struct
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from glb_add_clips import read, write

NCOMP = {"SCALAR": 1, "VEC3": 3, "VEC4": 4, "MAT4": 16}
DTYPE = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
BREATH_AT = (0.0, 0.36, 0.08)  # m under hips (glTF: up, back): the back of the rib cage, 1.22 m up on the v2 body
BREATH_BAND = (1.00, 1.10, 1.27, 1.36)  # m up: hips weights between the inner two go whole to x_breath, ramped outside
BREATH_HALF = (0.17, 0.25)  # m out from the middle: the band fades before the shoulders and arms
TIP = "weapon_muzzle"                 # the sword's point, on hand.R


def rest(j):
    return {n["name"]: (np.array(n.get("translation", [0, 0, 0]), np.float64),
                        np.array(n.get("rotation", [0, 0, 0, 1]), np.float64)) for n in j["nodes"]}


def span(j, i):
    ac = j["accessors"][i]
    bv = j["bufferViews"][ac["bufferView"]]
    assert "byteStride" not in bv, "interleaved attributes"
    k = NCOMP[ac["type"]]
    off = bv.get("byteOffset", 0) + ac.get("byteOffset", 0)
    dt = DTYPE[ac["componentType"]]
    return off, ac["count"], k, dt


def get(j, b, i):
    off, n, k, dt = span(j, i)
    return np.frombuffer(bytes(b[off:off + n * k * np.dtype(dt).itemsize]), dt).reshape(n, k)


def set_(j, b, i, arr):
    off, n, k, dt = span(j, i)
    assert arr.shape == (n, k)
    b[off:off + arr.nbytes] = arr.astype(dt).tobytes()


def put(j, b, arr, typ):
    b.extend(b"\0" * (-len(b) % 4))
    j["bufferViews"].append({"buffer": 0, "byteOffset": len(b), "byteLength": arr.nbytes})
    b.extend(arr.tobytes())
    ac = {"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126, "count": len(arr), "type": typ}
    if typ == "SCALAR":
        ac["min"], ac["max"] = [float(arr.min())], [float(arr.max())]
    j["accessors"].append(ac)
    return len(j["accessors"]) - 1


def smooth(a, c, x):
    x = np.clip((x - a) / (c - a), 0.0, 1.0)
    return x * x * (3 - 2 * x)


def add_breath(j, b):
    """The x_breath leaf: node, skin joint (bind = hips' bind moved to BREATH_AT) and the chest band's hips weights.
    -> vertices moved."""
    names = [n["name"] for n in j["nodes"]]
    if "x_breath" in names:
        return 0
    hips = names.index("hips")
    j["nodes"].append({"name": "x_breath", "translation": list(BREATH_AT)})
    xi = len(j["nodes"]) - 1
    j["nodes"][hips].setdefault("children", []).append(xi)
    skin = j["skins"][0]
    hj = skin["joints"].index(hips)
    M = get(j, b, skin["inverseBindMatrices"]).astype(np.float64).reshape(-1, 4, 4).transpose(0, 2, 1)  # column-major
    T = np.eye(4)
    T[:3, 3] = BREATH_AT
    Mx = np.linalg.inv(T) @ M[hj]
    allm = np.concatenate([M, Mx[None]], 0).transpose(0, 2, 1).reshape(-1, 16).astype(np.float32)
    skin["joints"].append(xi)
    xj = len(skin["joints"]) - 1
    moved = 0
    for m in j["meshes"]:
        for p in m["primitives"]:
            at = p["attributes"]
            if "JOINTS_0" not in at:
                continue
            P = get(j, b, at["POSITION"])
            J = get(j, b, at["JOINTS_0"]).copy()
            W = get(j, b, at["WEIGHTS_0"]).astype(np.float32).copy()
            y, x = P[:, 1], np.abs(P[:, 0])
            f = (smooth(BREATH_BAND[0], BREATH_BAND[1], y) * (1 - smooth(BREATH_BAND[2], BREATH_BAND[3], y))
                 * (1 - smooth(BREATH_HALF[0], BREATH_HALF[1], x)))
            for i in np.nonzero(f > 1e-3)[0]:
                slot = np.nonzero((J[i] == hj) & (W[i] > 0))[0]
                if len(slot) == 0:
                    continue
                mv = float(f[i] * W[i, slot[0]])
                W[i, slot[0]] -= mv
                free = np.nonzero(W[i] <= 0)[0]
                k = free[0] if len(free) else int(np.argmin(W[i]))
                J[i, k], W[i, k] = xj, mv
                W[i] /= W[i].sum()
                moved += 1
            set_(j, b, at["JOINTS_0"], J)
            set_(j, b, at["WEIGHTS_0"], W)
    skin["inverseBindMatrices"] = put(j, b, allm, "MAT4")
    return moved


def quat_mat(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def tip_at(j, b, an):
    """The sword's point at a clip's first frame (FK root..hand.R from its first keys).
    The idle's sits on the ground."""
    names = [n["name"] for n in j["nodes"]]
    first = {}
    for ch in an["channels"]:
        sm = an["samplers"][ch["sampler"]]
        first[(ch["target"]["node"], ch["target"]["path"])] = get(j, b, sm["output"])[0]
    M = np.eye(4)
    for nm in ("root", "hips", "upper_arm.R", "forearm.R", "hand.R"):
        i = names.index(nm)
        n = j["nodes"][i]
        L = np.eye(4)
        L[:3, :3] = quat_mat(first.get((i, "rotation"), n.get("rotation", [0, 0, 0, 1])))
        L[:3, 3] = first.get((i, "translation"), n.get("translation", [0, 0, 0]))
        M = M @ L
    tip = M @ np.array(list(j["nodes"][names.index(TIP)]["translation"]) + [1.0])
    return tip[:3], M[:3, 3]


def main(old_p, new_p, out_p):
    oj, ob = read(old_p)
    nj, nb = read(new_p)
    moved = add_breath(nj, nb)
    o_rest, n_rest = rest(oj), rest(nj)
    nid = {n["name"]: i for i, n in enumerate(nj["nodes"])}
    src = {an["name"] for an in oj["animations"]}
    nj["animations"] = [an for an in nj["animations"] if an["name"] not in src]
    times = {}
    dropped = set()
    for an in oj["animations"]:
        out = {"name": an["name"], "channels": [], "samplers": []}
        for ch in an["channels"]:
            nm = oj["nodes"][ch["target"]["node"]]["name"]
            if nm not in nid or nm.startswith("spring"):
                dropped.add(nm)
                continue
            sm = an["samplers"][ch["sampler"]]
            assert sm.get("interpolation", "LINEAR") != "CUBICSPLINE"
            path = ch["target"]["path"]
            t = get(oj, ob, sm["input"]).copy()
            v = get(oj, ob, sm["output"]).copy()
            if sm["input"] not in times:
                times[sm["input"]] = put(nj, nb, t, "SCALAR")
            if path == "translation":
                v += (n_rest[nm][0] - o_rest[nm][0]).astype(np.float32)
            out["samplers"].append({"input": times[sm["input"]], "interpolation": sm.get("interpolation", "LINEAR"),
                                    "output": put(nj, nb, v, "VEC4" if path == "rotation" else "VEC3")})
            out["channels"].append({"sampler": len(out["samplers"]) - 1, "target": {"node": nid[nm], "path": path}})
        nj["animations"].append(out)
        if an["name"] in ("idle", "stance"):
            tip, hand = tip_at(nj, nb, out)
            print("%s: sword point at x %.2f up %.3f fwd %.2f; hand.R up %.2f"
                  % (an["name"], tip[0], tip[1], -tip[2], hand[1]))
    write(out_p, nj, nb)
    drift = [k for k in n_rest if k in o_rest and not k.startswith("spring")
             and abs(float(np.dot(o_rest[k][1], n_rest[k][1]))) < 0.99999]
    print("clips", len(nj["animations"]), "replaced", len(src), "dropped", len(dropped), "breath verts", moved,
          "rest rotation drift", drift)


if __name__ == "__main__":
    main(*sys.argv[sys.argv.index("--") + 1:][:3])
