"""Kael's clips: the 49 hand-keyed clips of the first Kael (ext/art1-kael-2, 67 bones) copied onto the stage model's rig by bone name.
The two rigs share every rest rotation of the bones they have in common, so each rotation track copies as is. The stage model's legs are
shorter (hips 0.651 m over the ground, the first's 0.878), so a translation track keeps its motion scaled by that ratio and takes the new rest
as its base (new = new rest + (old - old rest) * k: a crouch drops the hips as far as the shorter legs bend). Bones only the first rig had (lids, brows, fingers, thumb, feet, the scarftail and centre-mane springs) are dropped, and
springs go untracked (the game's spring chains drive them from the rest pose).
The sword, an unskinned `weapon` mesh in the Gun's space, is skinned whole to hand.R, laid along the first Kael's blade (its guard on
anchor_blade_root, its point on weapon_muzzle, both added under hand.R), so the clips swing it (warden_anim kael.json "skinned_weapon").
Run with Blender's python (numpy): blender -b --factory-startup --python tools/art1/kael_retarget.py -- <old.glb> <kael.glb> <out.glb>"""
import os
import struct
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from glb_add_clips import read, write

PAD = {"dash": 0.9}     # clip: the length the kit's move keys run to (the first kit's dash was 0.42 s, this one holds its recovery): the last pose holds
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
GUARD_Z = -0.12         # the sword's guard along its -Z (the grip is at 0, the point at -0.62)
POINT_Z = -0.62
SWORD_SCALE = 1.2077    # the size it was drawn at in the hand (Gun 1.42 x warden_look weapon_scale 0.85)


def rest(j):
    return {n["name"]: (np.array(n.get("translation", [0, 0, 0]), np.float64), np.array(n.get("rotation", [0, 0, 0, 1]), np.float64)) for n in j["nodes"]}


def get(j, b, i):
    ac = j["accessors"][i]
    bv = j["bufferViews"][ac["bufferView"]]
    k = NCOMP[ac["type"]]
    off = bv.get("byteOffset", 0) + ac.get("byteOffset", 0)
    return np.frombuffer(bytes(b[off:off + ac["count"] * k * 4]), np.float32).reshape(ac["count"], k)


def put(j, b, arr, typ):
    b.extend(b"\0" * (-len(b) % 4))
    j["bufferViews"].append({"buffer": 0, "byteOffset": len(b), "byteLength": arr.nbytes})
    b.extend(arr.tobytes())
    ac = {"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126, "count": len(arr), "type": typ}
    if typ == "SCALAR":
        ac["min"], ac["max"] = [float(arr.min())], [float(arr.max())]
    j["accessors"].append(ac)
    return len(j["accessors"]) - 1


def main(old_p, new_p, out_p):
    oj, ob = read(old_p)
    nj, nb = read(new_p)
    o_rest, n_rest = rest(oj), rest(nj)
    k = n_rest["hips"][0][1] / o_rest["hips"][0][1]
    nid = {n["name"]: i for i, n in enumerate(nj["nodes"])}
    nj["animations"] = []
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
            if an["name"] in PAD and t[-1] < PAD[an["name"]]:
                t = np.append(t, np.float32(PAD[an["name"]]))
                v = np.vstack([v, v[-1:]])
            if (an["name"] in PAD, sm["input"]) not in times:
                times[(an["name"] in PAD, sm["input"])] = put(nj, nb, t, "SCALAR")
            if path == "translation":
                v = (n_rest[nm][0] + (v - o_rest[nm][0]) * k).astype(np.float32)
            out["samplers"].append({"input": times[(an["name"] in PAD, sm["input"])], "output": put(nj, nb, v, "VEC4" if path == "rotation" else "VEC3"),
                                    "interpolation": sm.get("interpolation", "LINEAR")})
            out["channels"].append({"sampler": len(out["samplers"]) - 1, "target": {"node": nid[nm], "path": path}})
        nj["animations"].append(out)
    sword(oj, nj, nb)
    write(out_p, nj, nb)
    drift = [k for k in n_rest if k in o_rest and not k.startswith("spring") and abs(float(np.dot(o_rest[k][1], n_rest[k][1]))) < 0.99999]
    print("clips", len(nj["animations"]), "dropped", len(dropped), "rest rotation drift", drift)


def sword(oj, nj, nb):
    """Skins `weapon` to hand.R along the first Kael's blade and adds its two empties under hand.R."""
    on = {n["name"]: n for n in oj["nodes"]}
    root = np.array(on["anchor_blade_root"]["translation"], np.float64)
    tip0 = np.array(on["weapon_muzzle"]["translation"], np.float64)
    d = (tip0 - root) * np.array([0, 1, 1])
    d /= np.linalg.norm(d)
    x = np.array([1.0, 0, 0])
    e = np.cross(-d, x)                      # (x, e, -d) right-handed: the sword's X, Y, Z in the hand
    rot = np.stack([x, e, -d], 1) * SWORD_SCALE
    at = root + SWORD_SCALE * GUARD_Z * d    # the grip, so the guard sits on anchor_blade_root
    tip = at + rot @ np.array([0, 0, POINT_Z])
    nid = {n["name"]: i for i, n in enumerate(nj["nodes"])}
    skin = nj["skins"][0]
    hj = skin["joints"].index(nid["hand.R"])
    ibm = get(nj, nb, skin["inverseBindMatrices"])[hj].reshape(4, 4).T.astype(np.float64)
    bind = np.linalg.inv(ibm)                # hand.R space -> the bind (model) space
    m = np.eye(4)
    m[:3, :3], m[:3, 3] = rot, at
    m = bind @ m
    wi = nid["weapon"]
    w = nj["nodes"][wi]
    assert "translation" not in w and "rotation" not in w and "scale" not in w and "children" not in w
    for p in nj["meshes"][w["mesh"]]["primitives"]:
        a = p["attributes"]
        pos = get(nj, nb, a["POSITION"]).astype(np.float64)
        pos = (pos @ m[:3, :3].T + m[:3, 3]).astype(np.float32)
        a["POSITION"] = put(nj, nb, pos, "VEC3")
        nj["accessors"][a["POSITION"]]["min"] = pos.min(0).tolist()
        nj["accessors"][a["POSITION"]]["max"] = pos.max(0).tolist()
        nrm = get(nj, nb, a["NORMAL"]).astype(np.float64) @ m[:3, :3].T
        a["NORMAL"] = put(nj, nb, (nrm / np.linalg.norm(nrm, axis=1, keepdims=True)).astype(np.float32), "VEC3")
        n = len(pos)
        a["JOINTS_0"] = put_u8(nj, nb, np.tile(np.array([hj, 0, 0, 0], np.uint8), (n, 1)))
        a["WEIGHTS_0"] = put(nj, nb, np.tile(np.array([1, 0, 0, 0], np.float32), (n, 1)), "VEC4")
    w["skin"] = 0
    sc = nj["scenes"][0]["nodes"]
    sc.remove(wi)
    arm = [i for i in sc if nj["nodes"][i]["name"] == "Armature"][0]
    nj["nodes"][arm]["children"].insert(0, wi)
    hand = nj["nodes"][nid["hand.R"]]
    for nm, p in (("anchor_blade_root", root), ("weapon_muzzle", tip)):
        nj["nodes"].append({"name": nm, "translation": [float(c) for c in p], "rotation": [0, 0, -1, 0]})
        hand.setdefault("children", []).append(len(nj["nodes"]) - 1)
    print("sword: root", np.round(root, 3), "point", np.round(tip, 3), "blade", round(float(np.linalg.norm(tip - root)), 3))


def put_u8(j, b, arr):
    b.extend(b"\0" * (-len(b) % 4))
    j["bufferViews"].append({"buffer": 0, "byteOffset": len(b), "byteLength": arr.nbytes})
    b.extend(arr.tobytes())
    j["accessors"].append({"bufferView": len(j["bufferViews"]) - 1, "componentType": 5121, "count": len(arr), "type": "VEC4"})
    return len(j["accessors"]) - 1


if __name__ == "__main__":
    main(*sys.argv[sys.argv.index("--") + 1:][:3])
