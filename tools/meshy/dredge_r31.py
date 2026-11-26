"""Grimble (dredge) native model, round 31 (plan: gens/hunter-round-1124/grimble/PLAN-1124o.md section 14).

  dredge_r31.py --pack-export OUT.glb IN.glb [--turn]     the pack primitives (material pack-meshy) as one untextured
                                                          mesh for a Meshy retexture (--original-uv); --turn spins it
                                                          180 deg about y so the pack's back (the side the game camera
                                                          sees) faces Meshy's front (+z)
  dredge_r31.py --pack-tex OUT.glb IN.glb MESHY.glb       the retextured pack's base colour (same UVs) in place of the
                                                          pack image (only pack-meshy uses it); nothing else changes
  dredge_r31.py --relax OUT.glb IN.glb [--goo] [--knee] [--target X] [--passes N]
                                                          skin weights blended toward their neighbours (r28's relax
                                                          loop) only where edges stretch past --target in any clip:
                                                          --goo = the skin-goo primitive (review D1: shards at the goo
                                                          root in Attack, goo stretch 3x live), with each horn rigid except
                                                          its collar (2 rings next to the goo); --knee = the
                                                          skin around both knees (D2: crack under the raised knee at
                                                          jump apex). Everything outside the mask keeps its weights.

Why: the game camera looks down on Grimble from behind, so the pack is most of what the player sees, and its Meshy
texture reads near-black/grey with orange specks (review D3, outfit/open_chest 5.5-6.0) against the turnaround's warm
brown wood crates, iron bands and the open gold-filled chest. Visible texture work goes through Meshy (owner rule);
this file only exports the mesh and swaps the image. numpy + PIL.
"""

import argparse
import io
import json
import os
import struct
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dredge_r29 import acc, add_view, compact, load, meshy_part, write  # noqa: E402
from dredge_r28 import _report, g, glb_add_clips, skin_relax, weld  # noqa: E402

PACK = "pack-meshy"


def pack_prims(js):
    return [p for p in js["meshes"][0]["primitives"] if js["materials"][p["material"]]["name"] == PACK]


def pack_export(o):
    js, b = load(o.inp)
    P, N, UV, F = [], [], [], []
    for pr in pack_prims(js):
        F.append(acc(js, b, pr["indices"]).reshape(-1, 3).astype(np.uint32) + sum(len(q) for q in P))
        P.append(acc(js, b, pr["attributes"]["POSITION"]).astype(np.float32))
        N.append(acc(js, b, pr["attributes"]["NORMAL"]).astype(np.float32))
        UV.append(acc(js, b, pr["attributes"]["TEXCOORD_0"]).astype(np.float32))
    P, N, UV, F = (np.concatenate(x) for x in (P, N, UV, F))
    if o.turn:
        P[:, [0, 2]] *= -1
        N[:, [0, 2]] *= -1
    P -= np.r_[0.0, P[:, 1].min(), 0.0].astype(np.float32)
    out = {"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"mesh": 0}],
           "buffers": [{}], "bufferViews": [], "accessors": [], "materials": [{"name": "pack"}],
           "meshes": [{"primitives": [{"attributes": {}, "indices": 0, "material": 0}]}]}
    ob = bytearray()

    def put(arr, ctype, typ, minmax=False):
        a = {"bufferView": add_view(out, ob, arr), "componentType": ctype, "count": len(arr), "type": typ}
        if minmax:
            a["min"], a["max"] = arr.min(0).tolist(), arr.max(0).tolist()
        out["accessors"].append(a)
        return len(out["accessors"]) - 1

    prim = out["meshes"][0]["primitives"][0]
    prim["indices"] = put(F.reshape(-1), 5125, "SCALAR")
    prim["attributes"] = {"POSITION": put(P, 5126, "VEC3", True), "NORMAL": put(N, 5126, "VEC3"),
                          "TEXCOORD_0": put(UV, 5126, "VEC2")}
    ob += b"\0" * (-len(ob) % 4)
    out["buffers"][0]["byteLength"] = len(ob)
    write(o.out, out, ob)
    print("wrote %s: pack %d verts %d tris, uv %s..%s" % (o.out, len(P), len(F), UV.min(0), UV.max(0)))


def pack_tex(o):
    js, b = load(o.inp)
    prims = pack_prims(js)
    tex = {js["materials"][p["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"] for p in prims}
    assert len(tex) == 1, "pack prims use more than one texture"
    t = tex.pop()
    users = [m for m in js["materials"] if m.get("pbrMetallicRoughness", {}).get("baseColorTexture", {}).get("index") == t]
    assert all(m["name"] == PACK for m in users), "pack texture shared with another material"
    _, _, _, img = meshy_part(o.meshy)
    old = js["images"][js["textures"][t]["source"]]
    v = js["bufferViews"][old["bufferView"]]
    w = Image.open(io.BytesIO(bytes(b[v.get("byteOffset", 0) : v.get("byteOffset", 0) + v["byteLength"]]))).size[0]
    size = max(w, min(o.size, img.size[0]))
    im = img.resize((size, size), Image.LANCZOS) if img.size[0] != size else img
    jb = io.BytesIO()
    im.save(jb, "JPEG", quality=90)
    js["images"][js["textures"][t]["source"]] = {"bufferView": add_view(js, b, np.frombuffer(jb.getvalue(), np.uint8)),
                                                 "mimeType": "image/jpeg"}
    b = compact(js, b)
    write(o.out, js, b)
    print("wrote %s: pack image %d px -> %d px from %s" % (o.out, w, size, o.meshy))


COLLAR = 2  # rings of horn vertices next to the plain goo that relax with it (the rest of each horn stays rigid)
KNEE = ((-0.40, 0.38, -0.30), (0.40, 0.78, 0.30))  # rest pose box round both knees (knee joints ~y 0.58), m
RAMP = 0.06  # m: inside the knee box's top and bottom faces the new weights fade in over this


def relax(o):
    j, bin_ = glb_add_clips.read(o.inp)
    skin = j["skins"][0]
    pz, _ = g.poses(j, bin_, skin)
    mats = [j["materials"][p["material"]]["name"] for p in j["meshes"][0]["primitives"]]
    for name, prims in g.skinned(j, bin_).items():
        rest, w, maps = weld(prims, len(skin["joints"]))
        tris = g.triangles(prims, maps)
        s = skin_relax.Skin.of(rest, w, g.edges_of(tris))
        mask = np.zeros(len(rest), bool)
        fade = np.ones(len(rest))
        if o.goo:
            gi = mats.index("skin-goo")
            mask[maps[gi]] = True
            # The horn prim indexes the goo's own vertex buffer, so its vertices are goo vertices with rigid weights
            # (r30). The worst goo stretch (26x, the review's cream shards at the root) is on horn-to-goo edges: the
            # horn's collar (horn vertices within COLLAR rings of a plain goo vertex) relaxes with the goo; the rest of
            # each horn keeps its weights (rigid).
            hv = np.zeros(len(rest), bool)
            hv[np.unique(tris[mats.index("leather-horn")])] = True
            free = mask & ~hv
            for _ in range(COLLAR):
                hit = free[s.edges[:, 0]] | free[s.edges[:, 1]]
                free[s.edges[hit].ravel()] = True
            near = mask & hv & ~free
            mask &= ~near
            print("goo: %d verts relaxable, %d horn verts kept rigid" % (mask.sum(), near.sum()))
        if o.knee:
            lo, hi = map(np.array, KNEE)
            k = ((rest >= lo) & (rest <= hi)).all(1)
            for m, mt in enumerate(mats):  # skin only (not goo, gauntlet, pack)
                if mt not in ("skin-native",):
                    k[maps[m]] = False
            fade = np.where(k, np.clip(np.minimum(rest[:, 1] - lo[1], hi[1] - rest[:, 1]) / RAMP, 0, 1), fade)
            mask |= k
            print("knee: %d verts in box" % k.sum())
        orig = s.w.copy()
        f = (fade * mask)[:, None]
        worst = _report("before " + name, s, pz, mask)
        for it in range(o.passes):
            bad = (worst > o.target) & mask[s.edges].all(1)
            if not bad.any():
                break
            s.relax_once(bad)
            s.w = orig * (1.0 - f) + s.w * f
            s.w /= np.maximum(s.w.sum(1, keepdims=True), 1e-9)
            worst, _ = s.stretch(pz)
        _report("after  %s (%d passes)" % (name, it + 1), s, pz, mask)
        g.store(bin_, prims, s.w, maps, tris)
    glb_add_clips.write(o.out, j, bin_)


def main():
    ap = argparse.ArgumentParser()
    grp = ap.add_mutually_exclusive_group(required=True)
    grp.add_argument("--pack-export", action="store_true")
    grp.add_argument("--pack-tex", action="store_true")
    grp.add_argument("--relax", action="store_true")
    ap.add_argument("out")
    ap.add_argument("inp")
    ap.add_argument("meshy", nargs="?")
    ap.add_argument("--turn", action="store_true")
    ap.add_argument("--size", type=int, default=2048, help="pack image size cap (px)")
    ap.add_argument("--goo", action="store_true")
    ap.add_argument("--knee", action="store_true")
    ap.add_argument("--target", type=float, default=3.0, help="x rest length: masked edges over this relax")
    ap.add_argument("--passes", type=int, default=60)
    o = ap.parse_args()
    (pack_export if o.pack_export else pack_tex if o.pack_tex else relax)(o)


if __name__ == "__main__":
    main()
