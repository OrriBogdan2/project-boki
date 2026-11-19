"""Re-binds a Hero .glb's limb chains in another pose (numpy only, no Blender): the named bones' rest rotations become a
clip frame's (default: idle at 0 s), their inverse bind matrices follow, and the skinned mesh is posed into that rest by
its own weights, so the model looks the same at rest and every clip plays exactly as before (glTF clips key absolute
local rotations; every clip of a Hero keys its arms). Used before a v95 swap (v95_swap.py, WORK/game.glb): the swap's fit
puts the master's limbs on the rig's bones, so a rig bound with the arms hanging (0 deg) folds a master's clear arms into
the coat and hips, and every clip that lifts them 40-95 deg tears the fused skin (job 20261119-145816-a5, cause A).
Bound at the idle pose the arms stay clear of the body and the clips swing them only a little away from it.
Two steps (Motley, rebuild-ostra-1119):
  python3 tools/art1/glb_rebind.py GAME.glb WORK/game.glb --bones upper_arm.L,upper_arm.R     # the rig re-bound at idle 0 s
  blender -b --factory-startup --python tools/art1/v95_swap.py -- SPEC WORK OUT.glb            # (Blender binds = rest)
  python3 tools/art1/glb_rebind.py OUT.glb OUT.glb --bones <same> --rest-from GAME.glb         # rest back, binds kept
The last step matters: WardenGlb drops a .glb whose rest bones are off their rig nodes (forearm.L 0.19 m off -> the
procedural model). With the old rest and the new binds every clip skins exactly as the swap relaxed it.
Run: python3 tools/art1/glb_rebind.py IN.glb OUT.glb [--clip idle] [--time 0] [--bones upper_arm.L,...] [--rest-from G.glb]"""

import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb_add_clips
from glb_relax import accessor, quat_matrix, sample

ARMS = "upper_arm.L,forearm.L,hand.L,upper_arm.R,forearm.R,hand.R"


def trs_matrix(nd):
    if "matrix" in nd:
        return np.array(nd["matrix"], float).reshape(4, 4).T
    m = np.eye(4)
    m[:3, :3] = quat_matrix(nd.get("rotation", [0, 0, 0, 1])) * np.array(nd.get("scale", [1, 1, 1]), float)[None, :]
    m[:3, 3] = nd.get("translation", [0, 0, 0])
    return m


def globals_of(j):
    nodes = j["nodes"]
    parent = {c: i for i, nd in enumerate(nodes) for c in nd.get("children", [])}
    out = {}

    def g(i):
        if i not in out:
            out[i] = trs_matrix(nodes[i]) if i not in parent else g(parent[i]) @ trs_matrix(nodes[i])
        return out[i]

    for i in range(len(nodes)):
        g(i)
    return out


def put(bin_, start, stride, rows, dt):
    for k, r in enumerate(rows):
        b = np.asarray(r, dt).tobytes()
        bin_[start + k * stride:start + k * stride + len(b)] = b


def rest_from(a):
    """After the swap: the named bones' rest TRS back to ORIG's (WardenGlb wants every rest bone on its rig node), the
    inverse bind matrices and the mesh as the swap bound them (in the re-bound pose). Every clip keys these bones'
    rotations, so no clip changes; only an unanimated rest view shows the arms pulled down to the old rest."""
    j, bin_ = glb_add_clips.read(a.src)
    oj, _ = glb_add_clips.read(a.rest_from)
    onames = {nd.get("name", ""): nd for nd in oj["nodes"]}
    for nd in j["nodes"]:
        if nd.get("name") in a.bones.split(","):
            o = onames[nd["name"]]
            for k in ("translation", "rotation", "scale"):
                if k in o:
                    nd[k] = o[k]
                else:
                    nd.pop(k, None)
    glb_add_clips.write(a.out, j, bin_)
    print("REBIND rest of %s back to %s's (binds kept)" % (a.bones, os.path.basename(a.rest_from)))


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--clip", default="idle")
    ap.add_argument("--time", type=float, default=0.0)
    ap.add_argument("--bones", default=ARMS)
    ap.add_argument("--rest-from", help="after the swap: put these bones' rest back to this .glb's, keep the binds")
    a = ap.parse_args(argv)
    if a.rest_from:
        return rest_from(a)
    j, bin_ = glb_add_clips.read(a.src)
    names = {nd.get("name", ""): i for i, nd in enumerate(j["nodes"])}
    want = [names[b] for b in a.bones.split(",")]
    anim = next(x for x in j["animations"] if x["name"] == a.clip)
    G0 = globals_of(j)
    for ch in anim["channels"]:
        nd, path = ch["target"]["node"], ch["target"]["path"]
        if nd in want and path == "rotation":
            s = anim["samplers"][ch["sampler"]]
            t = accessor(j, bin_, s["input"])[0].reshape(-1)
            v = accessor(j, bin_, s["output"])[0]
            q = np.asarray(sample(t, v, s.get("interpolation", "LINEAR"), path, a.time), float)
            j["nodes"][nd]["rotation"] = [float(x) for x in q / np.linalg.norm(q)]
    G1 = globals_of(j)
    for sk in j["skins"]:
        ibm, start, stride = accessor(j, bin_, sk["inverseBindMatrices"])
        ibm = ibm.reshape(-1, 4, 4).transpose(0, 2, 1).astype(float)
        # skin matrix at the new rest with the old binds: the mesh posed into the new rest
        pose = np.stack([G1[n] @ ibm[k] for k, n in enumerate(sk["joints"])])
        bind = np.stack([G0[n] @ ibm[k] for k, n in enumerate(sk["joints"])])       # (identity for a clean export)
        new_ibm = np.stack([np.linalg.inv(G1[n]) @ bind[k] for k, n in enumerate(sk["joints"])])
        put(bin_, start, stride, new_ibm.transpose(0, 2, 1).reshape(len(new_ibm), 16), np.float32)
        skin_index = j["skins"].index(sk)
        for nd in j["nodes"]:
            if nd.get("skin") != skin_index or "mesh" not in nd:
                continue
            for pr in j["meshes"][nd["mesh"]]["primitives"]:
                at = pr["attributes"]
                if "JOINTS_0" not in at:
                    continue
                J = accessor(j, bin_, at["JOINTS_0"])[0].astype(int)
                W = accessor(j, bin_, at["WEIGHTS_0"])[0].astype(float)
                W = W / np.maximum(W.sum(1, keepdims=True), 1e-9)     # (normalized ints too: the sum scales out)
                # bind frame -> posed, back to the bind frame (bind[k] is the same for every joint)
                M = np.einsum("nc,ncij->nij", W, np.linalg.inv(bind[0]) @ pose[J])
                P, ps, pst = accessor(j, bin_, at["POSITION"])
                P2 = np.einsum("nij,nj->ni", M, np.c_[P.astype(float), np.ones(len(P))])[:, :3]
                put(bin_, ps, pst, P2, np.float32)
                pa = j["accessors"][at["POSITION"]]
                pa["min"], pa["max"] = [float(x) for x in P2.min(0)], [float(x) for x in P2.max(0)]
                if "NORMAL" in at:
                    N, ns, nst = accessor(j, bin_, at["NORMAL"])
                    N2 = np.einsum("nij,nj->ni", M[:, :3, :3], N.astype(float))
                    N2 /= np.maximum(np.linalg.norm(N2, axis=1, keepdims=True), 1e-9)
                    put(bin_, ns, nst, N2, np.float32)
                if "TANGENT" in at:
                    T, ts, tst = accessor(j, bin_, at["TANGENT"])
                    T2 = np.einsum("nij,nj->ni", M[:, :3, :3], T[:, :3].astype(float))
                    T2 /= np.maximum(np.linalg.norm(T2, axis=1, keepdims=True), 1e-9)
                    put(bin_, ts, tst, np.c_[T2, T[:, 3]], np.float32)
    glb_add_clips.write(a.out, j, bin_)
    for b in a.bones.split(","):
        d0, d1 = G0[names[b]][:3, 1], G1[names[b]][:3, 1]
        print("REBIND %s: %.0f deg from the old rest" % (b, np.degrees(np.arccos(np.clip(d0 @ d1 / np.linalg.norm(d0) / np.linalg.norm(d1), -1, 1)))))


if __name__ == "__main__":
    main(sys.argv[1:])
