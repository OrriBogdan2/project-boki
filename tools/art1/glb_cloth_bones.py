"""Adds cloth bone chains to a warden .glb and re-skins its loose cloth to them (no Blender; mesh, UVs, textures,
clips and every contract bone stay byte-identical: only the cloth vertices' JOINTS_0/WEIGHTS_0 change in place, the
new nodes are appended, and the skin gets the extra joints). The game drives the chains with SpringBoneSimulator3D
(scripts/heroes/warden_cloth.gd); a chain is `cloth_<tag>_<i>`: _0 rides its parent rigidly, the last is the tip
(no skin of its own).

Run: python3 tools/art1/glb_cloth_bones.py <in.glb> <spec.json> [out.glb] [--report]
Spec (art/wardens/src/<art>_cloth.json), one entry per cloth group in "groups":
  mesh        mesh name holding the cloth (the body)
  parent      bone the chains hang from (hips)
  materials   material names that count as cloth
  from_bones  only vertices mostly skinned to these bones are cloth (the thighs: the skirt rides the legs now)
  extra_bones {material: [bones]} more bones that count for one material (cloth strands hanging over the shins)
  y           [low, high] vertical range (glTF Y up, metres at class-neutral size) the cloth hangs over
  center      [x, z] of the vertical axis the sectors fan around
  sectors     chains around it (sector 0 faces the front, -Z; they run toward +X, the wearer's right)
  levels      the joints' heights, top first (the first is rigid; the last skinned one carries everything below it)
  tip         height of the unskinned tip joint
  blend       share of a sector's width the angle blend covers (1 = linear between neighbours)
  outer       metres from the leg axis (x = +-leg_x) beyond which a thigh-skinned vertex of ANY material counts as cloth
  loose       {"max_verts": n, "rad": m, "below": y}: a small welded piece (a strand tip the colour slots put in another
              material) of ANY material, mostly skinned to from_bones, centred more than rad m from the leg axis and
              below y, counts as cloth whole (else it stays on the thigh while the skirt swings away: a stray bit)
  tag         bone tag (cloth_<tag><sector>_<i>)
Needs numpy."""
import json
import math
import os
import struct
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb_add_clips as G  # noqa: E402


def acc_data(j, b, i):
    ac = j["accessors"][i]
    bv = j["bufferViews"][ac["bufferView"]]
    off = bv.get("byteOffset", 0) + ac.get("byteOffset", 0)
    n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[ac["type"]]
    dt = {5126: "<f4", 5121: "u1", 5123: "<u2", 5125: "<u4"}[ac["componentType"]]
    return np.frombuffer(bytes(b), dtype=dt, count=ac["count"] * n, offset=off).reshape(ac["count"], n).copy(), off


def global_pos(nodes, parent, idx):
    """Rest position of a node in skeleton space (rotations are identity within 1e-7 on these rigs)."""
    p = np.zeros(3)
    while idx is not None:
        p += np.array(nodes[idx].get("translation", [0, 0, 0]))
        idx = parent.get(idx)
    return p


def build(j, b, spec):
    nodes = j["nodes"]
    parent = {c: i for i, n in enumerate(nodes) for c in n.get("children", [])}
    skin = j["skins"][0]
    joints = skin["joints"]
    jname = [nodes[n]["name"] for n in joints]
    mesh = next(m for m in j["meshes"] if m.get("name") == spec["mesh"])
    # gather the body's vertices
    pr_data = []
    for pr in mesh["primitives"]:
        pos, _ = acc_data(j, b, pr["attributes"]["POSITION"])
        jn, joff = acc_data(j, b, pr["attributes"]["JOINTS_0"])
        wt, woff = acc_data(j, b, pr["attributes"]["WEIGHTS_0"])
        pr_data.append((pr, pos, jn, wt, joff, woff, j["materials"][pr["material"]]["name"]))
    report = {}
    new_joint_nodes = []
    ibm_ac = skin["inverseBindMatrices"]
    ibm, _ = acc_data(j, b, ibm_ac)
    ibm = ibm.reshape(-1, 16)
    new_ibm = []
    parent_node = next(n for n in joints if nodes[n]["name"] == spec["parent"])
    parent_joint = jname.index(spec["parent"])
    par_pos = global_pos(nodes, parent, parent_node)
    sel_all = []
    for g in spec["groups"]:
        cx, cz = g["center"]
        ns = g["sectors"]
        levels = g["levels"]
        nl = len(levels)
        # which vertices are cloth
        picks = []
        for k, (pr, pos, jn, wt, joff, woff, mat) in enumerate(pr_data):
            dom = jn[np.arange(len(jn)), wt.argmax(1)]
            bones = g["from_bones"] + g.get("extra_bones", {}).get(mat, [])
            ok = np.array([jname[int(d)] in bones for d in dom])
            if mat not in g["materials"]:
                # (a strand the colour slots put in another material: far outside the legs, so not a leg)
                leg_x, out = g.get("leg_x", 0.09), g.get("outer", 0)
                ok &= (out > 0) & (np.hypot(np.abs(pos[:, 0]) - leg_x, pos[:, 2] - cz) > out)
            lo = g.get("loose")
            if lo and mat not in g["materials"]:
                ok |= loose_pieces(j, b, pr, pos, dom, [jname.index(n) for n in g["from_bones"]], lo, g.get("leg_x", 0.09), cz)
            ok &= (pos[:, 1] >= g["y"][0]) & (pos[:, 1] <= g["y"][1])
            picks.append((k, np.where(ok)[0]))
        allp = np.concatenate([pr_data[k][1][ix] for k, ix in picks])
        ang = np.degrees(np.arctan2(allp[:, 0] - cx, -(allp[:, 2] - cz))) % 360.0
        width = 360.0 / ns
        # joint positions: the mean of the cloth in each (sector, height band)
        jp = np.zeros((ns, nl, 3))
        for s in range(ns):
            da = np.abs((ang - s * width + 180) % 360 - 180)
            for li, y in enumerate(levels):
                half = (levels[li - 1] - levels[li]) / 2 if li > 0 else (levels[0] - levels[1]) / 2
                m = (da < width * 0.6) & (np.abs(allp[:, 1] - y) < max(half, 0.05))
                if m.sum() >= 3:
                    p = allp[m].mean(0)
                    jp[s, li] = [p[0], y, p[2]]
                else:
                    a = math.radians(s * width)
                    r = 0.18
                    jp[s, li] = [cx + r * math.sin(a), y, cz - r * math.cos(a)]
        # a sector's chain hangs without crossing: keep the top joint on the belt line
        tags = []
        base = len(nodes)
        for s in range(ns):
            tag = "cloth_%s%d" % (g["tag"], s)
            prev_pos = par_pos
            prev_node = parent_node
            for li in range(nl + 1):
                p = jp[s, li] if li < nl else np.array([jp[s, nl - 1, 0] * 1.0, g["tip"], jp[s, nl - 1, 2]])
                local = (p - prev_pos).tolist()
                nodes.append({"name": "%s_%d" % (tag, li), "translation": [float(x) for x in local]})
                idx = len(nodes) - 1
                nodes[prev_node].setdefault("children", []).append(idx)
                parent[idx] = prev_node
                new_ibm.append(np.linalg.inv(_t(p)).T.reshape(16))      # bind = inverse of its global rest
                new_joint_nodes.append(idx)
                prev_pos = p
                prev_node = idx
        # joint index of cloth_<tag><s>_<li> in the skin
        first = len(joints) + len(new_joint_nodes) - ns * (nl + 1)

        def jid(s, li):
            return first + (s % ns) * (nl + 1) + li
        # re-skin
        cnt = 0
        for k, ix in picks:
            pr, pos, jn, wt, joff, woff, mat = pr_data[k]
            for v in ix:
                p = pos[v]
                a = math.degrees(math.atan2(p[0] - cx, -(p[2] - cz))) % 360.0
                s0 = int(a // width) % ns
                t = (a - s0 * width) / width      # 0..1 from sector s0's centre-line to the next
                # centre-line of sector s is at s*width; blend neighbours over the middle `blend` share
                t = float(np.clip((t - 0.5 * (1 - g["blend"])) / g["blend"], 0.0, 1.0))
                t = t * t * (3 - 2 * t)
                # height: between level li and li+1
                y = p[1]
                if y >= levels[0]:
                    inf = {parent_joint: 1.0}      # above the top joint: rides the parent rigidly (the belt)
                    li, f = -1, 0.0
                elif y <= levels[nl - 1]:
                    li, f = nl - 1, 0.0
                else:
                    li = next(i for i in range(nl - 1) if levels[i] >= y > levels[i + 1])
                    f = (levels[li] - y) / (levels[li] - levels[li + 1])
                    f = f * f * (3 - 2 * f)
                if li >= 0:
                    inf = {}
                for s, ws in ((s0, 1 - t), ((s0 + 1) % ns, t)):
                    if ws <= 1e-4 or li < 0:
                        continue
                    inf[jid(s, li)] = inf.get(jid(s, li), 0) + ws * (1 - f)
                    if f > 1e-4:
                        inf[jid(s, li + 1)] = inf.get(jid(s, li + 1), 0) + ws * f
                top = sorted(inf.items(), key=lambda kv: -kv[1])[:4]
                tot = sum(w for _, w in top)
                jn[v] = 0
                wt[v] = 0
                for c, (jj, w) in enumerate(top):
                    jn[v, c] = jj
                    wt[v, c] = w / tot
                cnt += 1
            sel_all.append((k, ix))
        report[g["tag"]] = {"verts": cnt, "joints": ns * (nl + 1)}
    # write the weights back in place
    for pr, pos, jn, wt, joff, woff, mat in pr_data:
        jb = jn.astype(np.uint8).tobytes()
        b[joff:joff + len(jb)] = jb
        wb = wt.astype("<f4").tobytes()
        b[woff:woff + len(wb)] = wb
    # extend the skin
    skin["joints"] = joints + new_joint_nodes
    ibm_all = np.concatenate([ibm, np.array(new_ibm)]).astype("<f4")
    b.extend(b"\0" * (-len(b) % 4))
    j["bufferViews"].append({"buffer": 0, "byteOffset": len(b), "byteLength": ibm_all.nbytes})
    b.extend(ibm_all.tobytes())
    j["accessors"][ibm_ac] = {"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126,
                              "count": len(ibm_all), "type": "MAT4"}
    j["buffers"][0]["byteLength"] = len(b) + (-len(b) % 4)
    return report


def pieces(j, b, pr, pos):
    """Welded connected pieces of a primitive: a piece id per vertex (vertices at the same position are one)."""
    idx, _ = acc_data(j, b, pr["indices"])
    _, inv = np.unique(np.round(pos, 5), axis=0, return_inverse=True)
    inv = inv.ravel()
    par = np.arange(inv.max() + 1)

    def find(x):
        while par[x] != x:
            par[x] = par[par[x]]
            x = par[x]
        return x
    for a, c, d in inv[idx.reshape(-1, 3)]:
        r = find(a)
        par[find(c)] = r
        par[find(d)] = r
    return np.array([find(i) for i in inv])


def loose_pieces(j, b, pr, pos, dom, bones, lo, leg_x, cz):
    pid = pieces(j, b, pr, pos)
    ok = np.zeros(len(pos), bool)
    for p in np.unique(pid):
        vs = np.where(pid == p)[0]
        if len(vs) > lo["max_verts"] or np.isin(dom[vs], bones).mean() < 0.5:
            continue
        c = pos[vs].mean(0)
        if c[1] < lo["below"] and math.hypot(abs(c[0]) - leg_x, c[2] - cz) > lo["rad"]:
            ok[vs] = True
    return ok



def _t(p):
    m = np.eye(4)
    m[:3, 3] = p
    return m


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    j, b = G.read(args[0])
    spec = json.load(open(args[1]))
    rep = build(j, b, spec)
    out = args[2] if len(args) > 2 else args[0]
    G.write(out, j, b)
    print(json.dumps(rep), "->", out)


if __name__ == "__main__":
    main()
