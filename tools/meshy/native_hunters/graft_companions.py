"""Swaps Meeko's sun and cloud (the five companion surfaces of art/wardens/pip/pip_meshy.glb) for the ones
tools/art1/pip_companions_native.py builds: its geometry is taken in at 1.179 x (contract metres to Meshy units), turned
a half turn about Y (Meshy faces +Z) and put where the old part's bounding box sat; materials are renamed/recoloured
(`glow-sun`, `cloth-cloud`), the face atlas PNG replaced (face UVs 0..1 over a cell: WardenNative runs WardenMood). Everything else of IN.glb stays (body, skin, clips).
A body whose COMPANIONS.glb material has a base colour texture (the Meshy sun/cloud, 11-24) keeps its UVs and that image
(embedded as is; the builder already sized it); IN.glb may be an earlier graft (its materials already renamed).

  python3 graft_companions.py OUT.glb IN.glb COMPANIONS.glb FACES.png
"""

import sys

import numpy as np

sys.path.insert(0, __file__.rsplit("/", 2)[0])
import native_pack as npk  # noqa: E402

sys.path.insert(0, __file__.rsplit("/", 1)[0])
import graft  # noqa: E402

SCALE = 1.256 / 1.065
GROUPS = {"sun": ("cloth-sun", "eyes-mood_sun"), "cloud": ("skin-cloud", "ice-drop", "eyes-mood_cloud")}
NEW_NAME = {"cloth-sun": "glow-sun", "skin-cloud": "cloth-cloud"}  # material in IN.glb -> its name in the new file
SRC_NAME = {"cloth-sun": "glow-sun", "skin-cloud": "cloth-cloud"}  # ... and what COMPANIONS.glb calls it
FACES = ("eyes-mood_sun", "eyes-mood_cloud")


def prims(js, bin_):
    return {js["materials"][p["material"]]["name"]: p for m in js["meshes"] for p in m["primitives"]}


def carry_texture(js, out, mt, cjs, cbin, cm):
    """Puts COMPANIONS.glb material cm's base colour image on IN.glb material mt (replacing the image of an earlier graft)."""
    cimg = cjs["images"][cjs["textures"][cm["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]]
    view = out.add_view(npk.view_bytes(cjs, cbin, cimg["bufferView"]))
    pbr = mt.get("pbrMetallicRoughness", {})
    if "baseColorTexture" in pbr:
        img = js["images"][js["textures"][pbr["baseColorTexture"]["index"]]["source"]]
        img.update(bufferView=view, mimeType=cimg["mimeType"])
        return
    js["images"].append({"bufferView": view, "mimeType": cimg["mimeType"], "name": mt["name"] + "_albedo"})
    js["textures"].append({"sampler": 0, "source": len(js["images"]) - 1})
    mt["pbrMetallicRoughness"] = {
        "baseColorTexture": {"index": len(js["textures"]) - 1},
        "metallicFactor": 0,
        "roughnessFactor": cm["pbrMetallicRoughness"].get("roughnessFactor", 0.5),
    }


def main(out_path, in_path, comp_path, faces_png):
    js, bin_ = npk.load(in_path)
    cjs, cbin = npk.load(comp_path)
    old, new = prims(js, bin_), prims(cjs, cbin)
    old.update({n: old[NEW_NAME[n]] for n in NEW_NAME if n not in old and NEW_NAME[n] in old})  # (an earlier graft)
    cmat = {m["name"]: m for m in cjs["materials"]}
    out = npk.Out(js, bin_)
    for grp, names in GROUPS.items():
        lo = np.min([graft.read(js, bin_, old[n]["attributes"]["POSITION"]).min(0) for n in names], 0)
        hi = np.max([graft.read(js, bin_, old[n]["attributes"]["POSITION"]).max(0) for n in names], 0)
        old_c = (lo + hi) / 2
        src = {
            n: graft.read(cjs, cbin, new[SRC_NAME.get(n, n)]["attributes"]["POSITION"])
            * np.array([-1, 1, -1], np.float32)
            for n in names
        }
        nlo = np.min([v.min(0) for v in src.values()], 0)
        nhi = np.max([v.max(0) for v in src.values()], 0)
        for n in names:
            p, q = old[n], new[SRC_NAME.get(n, n)]
            pos = (src[n] - (nlo + nhi) / 2) * SCALE + old_c
            nrm = graft.read(cjs, cbin, q["attributes"]["NORMAL"]) * np.array([-1, 1, -1], np.float32)
            idx = graft.read(cjs, cbin, q["indices"]).ravel()
            textured = "baseColorTexture" in cmat[SRC_NAME.get(n, n)].get("pbrMetallicRoughness", {})
            if (
                n in FACES or textured
            ):  # (faces: 0..1 over the face's cell, WardenMood's atlas shader picks it; Meshy bodies: their atlas)
                uv = graft.read(cjs, cbin, q["attributes"]["TEXCOORD_0"])
            else:
                uv = np.tile(np.array([0.0, 1.0], np.float32), (len(pos), 1))
            joint = int(graft.read(js, bin_, p["attributes"]["JOINTS_0"])[0][0])
            n_v = len(pos)
            at = {
                "POSITION": pos,
                "NORMAL": nrm,
                "TEXCOORD_0": uv,
                "COLOR_0": np.ones((n_v, 4), np.float32),
                "COLOR_1": np.ones((n_v, 4), np.float32),
                "WEIGHTS_0": np.tile(np.array([1, 0, 0, 0], np.float32), (n_v, 1)),
            }
            for k, v in at.items():
                acc = {"componentType": 5126, "type": "SCALAR" if v.shape[1] == 1 else f"VEC{v.shape[1]}"}
                data = np.ascontiguousarray(v, np.float32)
                acc.update({"bufferView": out.add_view(data.tobytes()), "count": n_v})
                if k == "POSITION":
                    acc["min"], acc["max"] = data.min(0).tolist(), data.max(0).tolist()
                js["accessors"].append(acc)
                p["attributes"][k] = len(js["accessors"]) - 1
            jd = np.zeros((n_v, 4), np.uint16)
            jd[:, 0] = joint
            js["accessors"].append(
                {"componentType": 5123, "type": "VEC4", "count": n_v, "bufferView": out.add_view(jd.tobytes())}
            )
            p["attributes"]["JOINTS_0"] = len(js["accessors"]) - 1
            big = n_v > 65535
            js["accessors"].append(
                {
                    "componentType": 5125 if big else 5123,
                    "type": "SCALAR",
                    "count": len(idx),
                    "bufferView": out.add_view(idx.astype(np.uint32 if big else np.uint16).tobytes()),
                }
            )
            p["indices"] = len(js["accessors"]) - 1
            if n in NEW_NAME:
                mt = js["materials"][p["material"]]
                mt["name"] = NEW_NAME[n]
                if textured:
                    carry_texture(js, out, mt, cjs, cbin, cmat[SRC_NAME[n]])
                else:
                    mt["pbrMetallicRoughness"] = cmat[SRC_NAME[n]]["pbrMetallicRoughness"]
    face_mat = next(m for m in js["materials"] if m["name"] == "eyes-mood_sun")
    img = js["images"][js["textures"][face_mat["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]]
    img["bufferView"] = out.add_view(open(faces_png, "rb").read())
    graft.compact(out)
    out.write(out_path)
    print(out_path, f"{out.size / 1e6:.1f} MB bin")


if __name__ == "__main__":
    main(*sys.argv[1:5])
