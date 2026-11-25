"""Copies whole primitives (by material name) from one Meshy-native glb into another one's skinned mesh, with their
materials and textures, every vertex weighted 1.0 to one bone of the target's skin (found by name). Positions are
scaled about the origin (feet at y=0, both models facing +Z) by --scale, or by the two bodies' height ratio.
Made 11-25 for Meeko round 12: a rebuilt Meshy body takes main's sun and rain cloud surfaces (#764) unchanged; the game
cuts them out of the body at load and floats them (warden_companions), so the bone only holds them in the file.

  python3 tools/art1/glb_copy_prims.py OUT.glb DST.glb SRC.glb --mats=glow-sun,eyes-mood_sun,... [--bone=Spine02]
      [--scale=auto|F] [--fit=SRC_BODY.glb] [--name=NEW_MATERIAL_NAME]
--fit: SRC and DST are different frames (a part Meshy split off before the rig scaled and grounded the body): the
  bounding box of SRC_BODY.glb (the same body as DST's, before rigging) is mapped onto DST's body box (uniform scale
  by height, then the box centres in x/z and the floors in y), and the copied parts take the same map.
--like=MAT: the copied parts use a copy of DST's material MAT (its textures, nothing copied from SRC): a Meshy split
  part keeps the whole model's atlas and UVs, which the rigged body also kept.
--name: the copied material(s) renamed (one name, or a comma list in --mats order), e.g. meshy_textured-wing.
"""

import argparse
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "meshy"))
sys.path.insert(0, os.path.join(HERE, "..", "meshy", "native_hunters"))
import graft  # noqa: E402
import native_pack as npk  # noqa: E402


def height(js, bin_, skip):
    hi = [graft.read(js, bin_, p["attributes"]["POSITION"])[:, 1].max()
          for m in js["meshes"] for p in m["primitives"] if js["materials"][p["material"]]["name"] not in skip]
    return float(max(hi))


def box(js, bin_, skip=()):
    ps = [graft.read(js, bin_, p["attributes"]["POSITION"]) for m in js["meshes"] for p in m["primitives"]
          if js["materials"][p["material"]]["name"] not in skip]
    ps = np.concatenate(ps)
    return ps.min(0), ps.max(0)


def add_acc(out, arr, ctype, typ, minmax=False):
    js = out.js
    acc = {"bufferView": out.add_view(np.ascontiguousarray(arr).tobytes()), "componentType": ctype,
           "count": len(arr), "type": typ}
    if minmax:
        acc["min"], acc["max"] = arr.min(0).tolist(), arr.max(0).tolist()
    js["accessors"].append(acc)
    return len(js["accessors"]) - 1


def copy_texture(out, sjs, sbin, ti):
    """Texture ti of SRC (its image bytes and sampler) appended to OUT; returns the new texture index."""
    js = out.js
    st = sjs["textures"][ti]
    img = sjs["images"][st["source"]]
    js.setdefault("images", []).append({"bufferView": out.add_view(npk.view_bytes(sjs, sbin, img["bufferView"])),
                                        "mimeType": img["mimeType"], "name": img.get("name", "copied")})
    samp = {}
    if "sampler" in st:
        js.setdefault("samplers", []).append(dict(sjs["samplers"][st["sampler"]]))
        samp = {"sampler": len(js["samplers"]) - 1}
    js.setdefault("textures", []).append({"source": len(js["images"]) - 1, **samp})
    return len(js["textures"]) - 1


def copy_material(out, sjs, sbin, mi):
    m = json.loads(json.dumps(sjs["materials"][mi]))

    def fix(d):
        for k, v in list(d.items()):
            if isinstance(v, dict):
                if k.endswith("Texture") and "index" in v:
                    v["index"] = copy_texture(out, sjs, sbin, v["index"])
                fix(v)
    fix(m)
    out.js["materials"].append(m)
    return len(out.js["materials"]) - 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("dst")
    ap.add_argument("src")
    ap.add_argument("--mats", required=True)
    ap.add_argument("--bone", default="Spine02")
    ap.add_argument("--scale", default="auto")
    ap.add_argument("--fit", default="")
    ap.add_argument("--name", default="")
    ap.add_argument("--like", default="")
    o = ap.parse_args()
    mats = o.mats.split(",")
    js, bin_ = npk.load(o.dst)
    sjs, sbin = npk.load(o.src)
    s = (height(js, bin_, mats) / height(sjs, sbin, mats)) if o.scale == "auto" else float(o.scale)
    t = np.zeros(3, np.float32)
    if o.fit:
        fjs, fbin = npk.load(o.fit)
        lo, hi = box(fjs, fbin)
        dlo, dhi = box(js, bin_, mats)
        s = float((dhi[1] - dlo[1]) / (hi[1] - lo[1]))
        t = np.float32([(dlo[0] + dhi[0]) / 2 - s * (lo[0] + hi[0]) / 2, dlo[1] - s * lo[1],
                        (dlo[2] + dhi[2]) / 2 - s * (lo[2] + hi[2]) / 2])
    names = o.name.split(",") if o.name else []
    joint = graft.joint_names(js).index(o.bone)
    out = npk.Out(js, bin_)
    prims = js["meshes"][0]["primitives"]
    done = []
    made = {}
    for sm in sjs["meshes"]:
        for sp in sm["primitives"]:
            name = sjs["materials"][sp["material"]]["name"]
            if name not in mats and "*" not in mats:
                continue
            pos = graft.read(sjs, sbin, sp["attributes"]["POSITION"]).astype(np.float32) * s + t
            n_v = len(pos)
            at = {"POSITION": add_acc(out, pos, 5126, "VEC3", True)}
            for k in ("NORMAL", "TEXCOORD_0", "COLOR_0", "COLOR_1"):
                if k in sp["attributes"]:
                    v = graft.read(sjs, sbin, sp["attributes"][k]).astype(np.float32)
                    at[k] = add_acc(out, v, 5126, f"VEC{v.shape[1]}")
            jd = np.zeros((n_v, 4), np.uint16)
            jd[:, 0] = joint
            at["JOINTS_0"] = add_acc(out, jd, 5123, "VEC4")
            at["WEIGHTS_0"] = add_acc(out, np.tile(np.float32([1, 0, 0, 0]), (n_v, 1)), 5126, "VEC4")
            idx = graft.read(sjs, sbin, sp["indices"]).ravel()
            big = n_v > 65535
            ii = add_acc(out, idx.astype(np.uint32 if big else np.uint16), 5125 if big else 5123, "SCALAR")
            new_name = names[min(len(done), len(names) - 1)] if names else None
            if new_name in made:
                mi = made[new_name]
            elif o.like:
                js["materials"].append(json.loads(json.dumps(next(m for m in js["materials"] if m["name"] == o.like))))
                mi = len(js["materials"]) - 1
            else:
                mi = copy_material(out, sjs, sbin, sp["material"])
            if new_name:
                js["materials"][mi]["name"] = new_name
                made[new_name] = mi
            prims.append({"attributes": at, "indices": ii, "material": mi, "mode": sp.get("mode", 4)})
            done.append(name)
    graft.compact(out)
    out.write(o.out)
    print(o.out, f"scale {s:.4f} shift {t.round(4).tolist()}", "copied", done, "missing", [m for m in mats if m not in done])


if __name__ == "__main__":
    main()
