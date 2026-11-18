"""Adds one leaf bone (x_breath, the idle's rib cage) to a game .glb with no Blender.
The node is copied from a source build (its rest under the same parent) and joined to the skin (inverse bind = its own
rest inverse after the parent's). The parent's skin weight inside a zone moves onto it, as posekit.add_breath does in
Blender, and its tracks in the named clips are copied in. Every other byte of the target stays the same.
Run: python3 tools/art1/glb_add_bone.py <target.glb> <source.glb> <bone> [out.glb] --zone z0,z1,xh[,fade] [--clips a,b]
--zone is in Blender's frame (Z up, metres: the glTF y). Weight ramps up from z0, down to z1 and in from |x| = xh, each
over fade (0.08 for z, 0.05 for x), times the parent's weight: the shape of ostra_anim.rib_cage.
A vertex with no free influence slot gives up its smallest other one (back to the parent) if that one is smaller."""
import struct
import sys

import glb_add_clips as G


def mat(t=(0, 0, 0), q=(0, 0, 0, 1), s=(1, 1, 1)):
    x, y, z, w = q
    r = [
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ]
    return [[r[i][0] * s[0], r[i][1] * s[1], r[i][2] * s[2], t[i]] for i in range(3)] + [[0, 0, 0, 1]]


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def inv_rigid(m):
    """inverse of rotation+translation (a scale-free bone rest)"""
    r = [[m[j][i] for j in range(3)] for i in range(3)]
    t = [-sum(r[i][k] * m[k][3] for k in range(3)) for i in range(3)]
    return [r[i] + [t[i]] for i in range(3)] + [[0, 0, 0, 1]]


def view(j, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    if bv.get("byteStride") or "sparse" in a:
        raise SystemExit("accessor %d: strided or sparse, not handled" % i)
    return a, bv.get("byteOffset", 0) + a.get("byteOffset", 0)


def zone_w(z0, z1, xh, fz=0.08, fx=0.05):
    def f(x, z):
        c = lambda v: min(max(v, 0.0), 1.0)
        return c((z - z0) / fz) * c((z1 - z) / fz) * c((xh - abs(x)) / fx)
    return f


def add_bone(tj, tb, sj, sb, bone, weight, clips):
    tn = {n.get("name"): i for i, n in enumerate(tj["nodes"])}
    sn = {n.get("name"): i for i, n in enumerate(sj["nodes"])}
    if bone in tn:
        raise SystemExit("%s is already in the target" % bone)
    spar = next(i for i, n in enumerate(sj["nodes"]) if sn[bone] in n.get("children", []))
    pname = sj["nodes"][spar]["name"]
    if G.rest_moved(sj["nodes"][spar], tj["nodes"][tn[pname]]):
        print("warning: %s's rest differs between the builds; %s keeps the source's offset under it" % (pname, bone))
    node = {k: v for k, v in sj["nodes"][sn[bone]].items() if k in ("name", "translation", "rotation", "scale")}
    tj["nodes"].append(node)
    ni = len(tj["nodes"]) - 1
    tj["nodes"][tn[pname]].setdefault("children", []).append(ni)
    skins = [s for s in tj["skins"] if tn[pname] in s["joints"]]
    report = []
    for sk in skins:
        pj = sk["joints"].index(tn[pname])
        a, off = view(tj, sk["inverseBindMatrices"])
        col = struct.unpack_from("<16f", tb, off + 64 * pj)           # column-major
        ibm_p = [[col[c * 4 + r] for c in range(4)] for r in range(4)]
        loc = mat(node.get("translation", (0, 0, 0)), node.get("rotation", (0, 0, 0, 1)))
        ibm = mul(inv_rigid(loc), ibm_p)
        flat = [ibm[r][c] for c in range(4) for r in range(4)]
        tb.extend(b"\0" * (-len(tb) % 4))
        tj["bufferViews"].append({"buffer": 0, "byteOffset": len(tb), "byteLength": 64 * (a["count"] + 1)})
        tb.extend(tb[off:off + 64 * a["count"]])
        tb.extend(struct.pack("<16f", *flat))
        sk["inverseBindMatrices"] = len(tj["accessors"])
        ibv = len(tj["bufferViews"]) - 1
        tj["accessors"].append({"bufferView": ibv, "componentType": 5126, "count": a["count"] + 1, "type": "MAT4"})
        sk["joints"].append(ni)
        bj = len(sk["joints"]) - 1
        users = {mi for mi, n in enumerate(tj["nodes"]) if "mesh" in n and "skin" in n and tj["skins"][n["skin"]] is sk}
        done = set()
        for mi in sorted({tj["nodes"][u]["mesh"] for u in users}):
            for pr in tj["meshes"][mi]["primitives"]:
                at = pr["attributes"]
                if "JOINTS_0" not in at or at["JOINTS_0"] in done:
                    continue
                done.add(at["JOINTS_0"])
                ja, jo = view(tj, at["JOINTS_0"])
                wa, wo = view(tj, at["WEIGHTS_0"])
                pa, po = view(tj, at["POSITION"])
                if wa["componentType"] != 5126 or ja["componentType"] not in (5121, 5123):
                    raise SystemExit("weights must be float, joints u8/u16")
                if ja["componentType"] == 5121 and bj > 255:
                    raise SystemExit("u8 joints cannot name joint %d" % bj)
                jf = "<4B" if ja["componentType"] == 5121 else "<4H"
                js = 4 if ja["componentType"] == 5121 else 8
                moved = squeezed = 0
                for v in range(ja["count"]):
                    jn = list(struct.unpack_from(jf, tb, jo + js * v))
                    wt = list(struct.unpack_from("<4f", tb, wo + 16 * v))
                    k = next((k for k in range(4) if jn[k] == pj and wt[k] > 0), None)
                    if k is None:
                        continue
                    x, y, z = struct.unpack_from("<3f", tb, po + 12 * v)
                    w = weight(x, y) * wt[k]          # glTF y is Blender's z
                    if w <= 0.001:
                        continue
                    free = next((s for s in range(4) if wt[s] == 0), None)
                    if free is None:
                        s = min((s for s in range(4) if s != k), key=lambda s: wt[s])
                        if wt[s] >= w:
                            continue
                        wt[k] += wt[s]
                        free = s
                        squeezed += 1
                    wt[k] -= w
                    jn[free], wt[free] = bj, w
                    struct.pack_into(jf, tb, jo + js * v, *jn)
                    struct.pack_into("<4f", tb, wo + 16 * v, *wt)
                    moved += 1
                report.append((tj["meshes"][mi].get("name"), ja["count"], moved, squeezed))
    copied = []
    for sa in sj.get("animations", []):
        if sa["name"] not in clips:
            continue
        ta = next((a for a in tj["animations"] if a["name"] == sa["name"]), None)
        if ta is None:
            raise SystemExit("no clip %s in the target" % sa["name"])
        for ch in sa["channels"]:
            if ch["target"]["node"] != sn[bone]:
                continue
            sm = sa["samplers"][ch["sampler"]]
            acc = []
            for key in ("input", "output"):
                a = dict(sj["accessors"][sm[key]])
                bv = sj["bufferViews"][a["bufferView"]]
                o, n = bv.get("byteOffset", 0) + a.get("byteOffset", 0), bv["byteLength"] - a.get("byteOffset", 0)
                tb.extend(b"\0" * (-len(tb) % 4))
                tj["bufferViews"].append({"buffer": 0, "byteOffset": len(tb), "byteLength": n})
                tb.extend(sb[o:o + n])
                a["bufferView"], a["byteOffset"] = len(tj["bufferViews"]) - 1, 0
                tj["accessors"].append(a)
                acc.append(len(tj["accessors"]) - 1)
            interp = sm.get("interpolation", "LINEAR")
            ta["samplers"].append({"input": acc[0], "output": acc[1], "interpolation": interp})
            tgt = {"node": ni, "path": ch["target"]["path"]}
            ta["channels"].append({"sampler": len(ta["samplers"]) - 1, "target": tgt})
            copied.append("%s.%s" % (sa["name"], ch["target"]["path"]))
    tj["buffers"][0]["byteLength"] = len(tb) + (-len(tb) % 4)
    return report, copied


if __name__ == "__main__":
    a = sys.argv[1:]
    z = [float(x) for x in a[a.index("--zone") + 1].split(",")]
    clips = a[a.index("--clips") + 1].split(",") if "--clips" in a else []
    pos = [x for i, x in enumerate(a) if not x.startswith("--") and (i == 0 or a[i - 1] not in ("--zone", "--clips"))]
    target, source, bone = pos[:3]
    out = pos[3] if len(pos) > 3 else target
    tj, tb = G.read(target)
    sj, sb = G.read(source)
    rep, cp = add_bone(tj, tb, sj, sb, bone, zone_w(*z), clips)
    G.write(out, tj, G.prune(tj, tb))
    for r in rep:
        print("mesh %s: %d verts, %d onto %s (%d gave up a small influence)" % (r[0], r[1], r[2], bone, r[3]))
    print("tracks copied:", cp)
