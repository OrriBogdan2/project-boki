"""Grimble (dredge) native model, round 28 stages on the r27 glb (plan: gens/hunter-round-1124/grimble/PLAN-1124o.md).

  dredge_r28.py --shoulder OUT IN   the goo-side shoulder tears in Attack (review D2: magenta streaks and black holes
                                    at the goo root, stretch 9.74x): the skin weights of the goo-side shoulder only
                                    (box SHOULDER) are blended toward their neighbours (skin_relax.relax_once) until
                                    no edge in that box stretches past TARGET in any clip, or PASSES run out. Every
                                    vertex outside the box keeps its weights byte for byte; no triangle is ripped.

  dredge_r28.py --horns OUT IN      the goo horns float off the goo arm in Attack/hit (review D4): each horn was rigid
                                    on one bone while the goo under its root follows a blend of GooTail bones. Each
                                    horn now takes the mean weights of the goo vertices within HORN_R of its root, so
                                    its root rides the goo surface (a horn stays rigid: one weight set per horn).

Measured with glb_relax's own skin maths (every clip, 0.1 s samples). numpy only.
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art1"))
import glb_add_clips  # noqa: E402
import glb_relax as g  # noqa: E402
import skin_relax  # noqa: E402

# goo-side shoulder (Meshy -x is the goo side): from the shoulder blade and collarbone up to under the ear, rest pose, m
SHOULDER = ((-0.45, 1.12, -0.45), (-0.02, 1.85, 0.30))
TARGET = 2.0  # x rest length: edges in the box over this are relaxed
PASSES = 80
RAMP = 0.08  # m: inside the box's lower and spine-side faces the new weights fade in over this (no seam where they meet)


def weld(prims, bones):
    """glb_relax.weld, but a joint listed twice (padding slots repeat joint 0 with weight 0) adds up as the game skins
    it: glb_relax's put_along_axis let the padding 0 overwrite a real joint-0 weight (weights summed to 0.26)."""
    allpos = np.concatenate([p["pos"] for p in prims])
    dense = np.zeros((len(allpos), bones))
    jo = np.concatenate([p["joints"] for p in prims])
    wt = np.concatenate([p["weights"] for p in prims])
    np.add.at(dense, (np.repeat(np.arange(len(allpos)), jo.shape[1]), jo.ravel()), wt.ravel())
    key = np.c_[np.round(allpos / g.WELD), np.round(dense / g.WELD_WEIGHT)].astype(np.int64)
    _, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
    inv = inv.ravel()
    sizes = np.cumsum([0] + [len(p["pos"]) for p in prims])
    return allpos[first], dense[first], [inv[a:b] for a, b in zip(sizes[:-1], sizes[1:])]


def _report(tag, s, pz, mask):
    worst, per = s.stretch(pz)
    inbox = mask[s.edges].all(1)
    byclip = {}
    for (c, _), r in zip(pz, per):
        byclip[c] = max(byclip.get(c, 0.0), float(r))
    print("%s: box edges >2x %d >3x %d >5x %d | worst per clip %s" % (
        tag, (worst[inbox] > 2).sum(), (worst[inbox] > 3).sum(), (worst[inbox] > 5).sum(),
        " ".join("%s %.2f" % (c.split("|")[-1][:10], v) for c, v in sorted(byclip.items()))))
    return worst


def shoulder(out, src):
    j, bin_ = glb_add_clips.read(src)
    skin = j["skins"][0]
    pz, _ = g.poses(j, bin_, skin)
    for name, prims in g.skinned(j, bin_).items():
        rest, w, maps = weld(prims, len(skin["joints"]))
        tris = g.triangles(prims, maps)
        s = skin_relax.Skin.of(rest, w, g.edges_of(tris))
        lo, hi = map(np.array, SHOULDER)
        mask = ((rest >= lo) & (rest <= hi)).all(1)
        if not mask.any():
            continue
        orig = s.w.copy()
        # fade: 0 on the box's lower face (y lo) and spine-side face (x hi), 1 from RAMP inside them
        f = np.clip(np.minimum(rest[:, 1] - lo[1], hi[0] - rest[:, 0]) / RAMP, 0.0, 1.0)[:, None] * mask[:, None]
        worst = _report("before " + name, s, pz, mask)
        for it in range(PASSES):
            bad = (worst > TARGET) & mask[s.edges].all(1)
            if not bad.any():
                break
            s.relax_once(bad)
            s.w = orig * (1.0 - f) + s.w * f
            s.w /= np.maximum(s.w.sum(1, keepdims=True), 1e-9)
            worst, _ = s.stretch(pz)
        _report("after  %s (%d passes, %d verts in box)" % (name, it + 1, mask.sum()), s, pz, mask)
        g.store(bin_, prims, s.w, maps, tris)
    glb_add_clips.write(out, j, bin_)


HORN_R = 0.06  # m: goo vertices this close to a horn's root give it their weights


def _skinned_pts(P, J, W, mats):
    """Positions of points P (weights J/W) under skinning matrices mats [joint, 4, 4]."""
    m = np.einsum("nk,nkij->nij", W, mats[J])
    return np.einsum("nij,nj->ni", m[:, :3], np.c_[P, np.ones(len(P))])


def horns(out, src):
    j, bin_ = glb_add_clips.read(src)
    skin = j["skins"][0]
    pz, _ = g.poses(j, bin_, skin)
    prims = g.skinned(j, bin_)["Mesh_0"]
    mats = [j["materials"][p["material"]]["name"] for p in j["meshes"][0]["primitives"]]
    goo = prims[mats.index("skin-goo")]
    for k, name in enumerate(mats):
        if name != "leather-horn":
            continue
        h = prims[k]
        d = np.linalg.norm(h["pos"][:, None, :] - goo["pos"][None, ::4, :], axis=2).min(1)
        root = h["pos"][d < d.min() + 0.03].mean(0)  # the horn's collar: its points nearest the goo
        near = np.linalg.norm(goo["pos"] - root, axis=1) < HORN_R
        dense = np.zeros(len(skin["joints"]))
        np.add.at(dense, goo["joints"][near].ravel(), goo["weights"][near].ravel())
        top = np.argsort(-dense)[:4]
        wt = dense[top] / dense[top].sum()
        top[wt == 0] = top[0]

        def gap(J, W):
            r = [np.linalg.norm(_skinned_pts(root[None], J, W, m)[0] - _skinned_pts(goo["pos"][near], goo["joints"][near], goo["weights"][near], m).mean(0)) for _, m in pz]
            r0 = np.linalg.norm(root - goo["pos"][near].mean(0))
            return max(abs(x - r0) for x in r)

        before = gap(h["joints"][:1], h["weights"][:1])
        after = gap(top[None], wt[None])
        jo_at, jo_st, jo_dt = h["jo"]
        wt_at, wt_st = h["wt"]
        for v in range(len(h["pos"])):
            o = jo_at + v * jo_st
            bin_[o : o + 4 * jo_dt.itemsize] = top.astype(jo_dt).tobytes()
            o = wt_at + v * wt_st
            bin_[o : o + 16] = wt.astype("<f4").tobytes()
        names = [j["nodes"][i]["name"] for i in skin["joints"]]
        print("horn prim %d root %s: %d goo verts; %s -> %s; root drift off the goo %.1f -> %.1f cm (all clips)" % (
            k, np.round(root, 2).tolist(), near.sum(), names[h["joints"][0, 0]],
            " ".join("%s %.2f" % (names[a], b) for a, b in zip(top, wt) if b > 0), 100 * before, 100 * after))
    glb_add_clips.write(out, j, bin_)


if __name__ == "__main__":
    STAGE = {"--shoulder": shoulder, "--horns": horns}
    if len(sys.argv) != 4 or sys.argv[1] not in STAGE:
        sys.exit(__doc__)
    STAGE[sys.argv[1]](sys.argv[2], sys.argv[3])
