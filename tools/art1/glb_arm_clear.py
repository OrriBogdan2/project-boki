"""Swings a hunter's arms out of its thighs and hips in every clip, with no Blender (Vex 11-23: her left hand sank 15-20 mm
into her left thigh in idle, dash, lmb and x, and the gun into her right thigh).

Run: python3 -I tools/art1/glb_arm_clear.py <mesh.glb> <in.glb> <out.glb> [<in2.glb> <out2.glb> ...] [--arms L,R]
     [--max-deg 24] [--margin 0.003] [--report out.tsv]
<mesh.glb> holds the skinned mesh (the hunter's .glb); every <in.glb> is a file with clips on the same rig (the .glb itself, or a
clips-only file like vex_cast_clips.glb, matched by node name).

For each clip and each key of upper_arm.<S>'s rotation track the mesh is posed (linear blend skinning, numpy). A vertex of
the arm below the elbow (forearm, hand, fingers, thumb, coin; for R the gun bones; the sleeve at the armpit touches the
jacket in the bind and a swing does not move it apart) is "inside" when it lies behind the
surface of thigh.<S> or hips (the median of its 5 nearest body vertices' normals) deeper than it does in the bind pose plus
--margin (L: thigh.L and hips; R: thigh.R only, the gun's cuff rests on the belt at the elbow). Per clip one swing axis is
picked: of 8 horizontal axes through the shoulder (in the hips' frame), the one that clears the clip's worst key by the
fewest degrees (out to the side first: forward/back costs 5 more degrees, the diagonals 3). Each key that clips then swings
about it by the smallest whole degree (up to --max-deg) that leaves no vertex inside. The swing angles are spread to the neighbour keys (max over +-2 keys, then a [1,2,1] blur), so
the arm eases out and back with no pop; a looping clip's first and last keys get the same swing. Only the upper_arm rotation
tracks of clips that clip change; each changed track gets its own new accessor (outputs can be shared between clips).
"""

import argparse
import sys

import numpy as np
from scipy.spatial import cKDTree

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from glb_add_clips import read, write  # noqa: E402

PARTS = {
    "thigh.L": ["thigh.L"], "thigh.R": ["thigh.R"], "hips": ["hips"],
    "arm.L": ["forearm.L", "hand.L", "fingers.L", "thumb.L", "coin"],
    "arm.R": ["forearm.R", "gatling", "launcher", "hand.R", "fingers.R", "thumb.R"],
}
OTHER = {"upper_arm.L", "upper_arm.R", "spine", "chest", "neck", "head", "shoulder.L", "shoulder.R", "shin.L", "shin.R", "foot.L", "foot.R"}
BODY = {"L": ["thigh.L", "hips"], "R": ["thigh.R"]}  # R: the gun's cuff rests on the belt at the elbow (a swing barely moves it)
AXIS_COST = {0: 0, 180: 0, 45: 3, 135: 3, 225: 3, 315: 3, 90: 5, 270: 5}  # degrees: an arm swings out before forward/back
REACH = 0.04  # m: a vertex further than this from the body surface is not tested


def acc(j, b, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    ct = {5126: "<f4", 5121: "u1", 5123: "<u2", 5125: "<u4"}[a["componentType"]]
    nc = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
    o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    return np.frombuffer(b, ct, a["count"] * nc, o).reshape(a["count"], nc).copy()


def qmul(a, b):
    x1, y1, z1, w1 = a
    x2, y2, z2, w2 = b
    return np.array([w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2, w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
                     w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2, w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2])


def qmat(q):
    x, y, z, w = q / np.linalg.norm(q)
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def axis_q(axis, ang):
    axis = axis / np.linalg.norm(axis)
    return np.append(axis * np.sin(ang / 2), np.cos(ang / 2))


class Skin:
    """The mesh of <mesh.glb>, posed from any clip whose channels name its nodes."""

    def __init__(self, path):
        j, b = read(path)
        self.nodes = j["nodes"]
        self.names = [n.get("name") for n in self.nodes]
        self.parent = {c: i for i, n in enumerate(self.nodes) for c in n.get("children", [])}
        sk = j["skins"][0]
        self.joints = sk["joints"]
        self.ib = acc(j, b, sk["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1).astype(float)
        self.mesh_node = next(i for i, n in enumerate(self.nodes) if "mesh" in n and "skin" in n)
        P, N, J, W = [], [], [], []
        for pr in j["meshes"][self.nodes[self.mesh_node]["mesh"]]["primitives"]:
            at = pr["attributes"]
            P.append(acc(j, b, at["POSITION"]).astype(float))
            N.append(acc(j, b, at["NORMAL"]).astype(float))
            J.append(acc(j, b, at["JOINTS_0"]).astype(int))
            w = acc(j, b, at["WEIGHTS_0"]).astype(float)
            W.append(w / 255.0 if w.max() > 1.5 else w)
        self.P, self.N, self.J, self.W = (np.concatenate(x) for x in (P, N, J, W))
        jn = [self.names[i] for i in self.joints]
        gw = {g: sum(self.W[:, c] * np.isin(self.J[:, c], [jn.index(x) for x in bs if x in jn]) for c in range(4))
              for g, bs in PARTS.items()}
        other = sum(self.W[:, c] * np.isin(self.J[:, c], [jn.index(x) for x in OTHER if x in jn]) for c in range(4))
        G = list(PARTS)
        st = np.stack([gw[g] for g in G] + [other], 1)
        lab = np.argmax(st, 1)
        self.part = {g: np.where(lab == i)[0] for i, g in enumerate(G)}

    def world(self, local):
        out = {}

        def w(i):
            if i not in out:
                n = self.nodes[i]
                q, t, s = local.get((i, "rotation")), local.get((i, "translation")), local.get((i, "scale"))
                q = np.array(n.get("rotation", [0, 0, 0, 1]), float) if q is None else q
                t = np.array(n.get("translation", [0, 0, 0]), float) if t is None else t
                s = np.array(n.get("scale", [1, 1, 1]), float) if s is None else s
                M = np.eye(4)
                M[:3, :3] = qmat(q) * s
                M[:3, 3] = t
                p = self.parent.get(i)
                out[i] = M if p is None else w(p) @ M
            return out[i]

        for i in range(len(self.nodes)):
            w(i)
        return out

    def pose(self, local, idx):
        Wd = self.world(local)
        inv = np.linalg.inv(Wd[self.mesh_node])
        S = np.array([inv @ Wd[jn] @ self.ib[k] for k, jn in enumerate(self.joints)])
        P = np.c_[self.P[idx], np.ones(len(idx))]
        out, nrm = np.zeros((len(idx), 3)), np.zeros((len(idx), 3))
        for c in range(4):
            M = S[self.J[idx, c]]
            w = self.W[idx, c : c + 1]
            out += w * np.einsum("nij,nj->ni", M[:, :3, :], P)
            nrm += w * np.einsum("nij,nj->ni", M[:, :3, :3], self.N[idx])
        return out, nrm / (np.linalg.norm(nrm, axis=1, keepdims=True) + 1e-12), Wd


def depth(Pa, Pb, Nb):
    """How far each vertex of Pa lies behind the surface (Pb, Nb): median of 5 neighbours, only if >= 4 are behind."""
    dist, k = cKDTree(Pb).query(Pa, k=5, distance_upper_bound=REACH)
    out = np.zeros(len(Pa))
    ok = np.isfinite(dist).all(1)
    if ok.any():
        d = -np.einsum("nkj,nkj->nk", Pa[ok][:, None, :] - Pb[k[ok]], Nb[k[ok]])
        behind = (d > 0.001).sum(1) >= 4
        out[np.where(ok)[0][behind]] = np.median(d, 1)[behind]
    return out


class Clips:
    def __init__(self, skin, path):
        self.skin, self.path = skin, path
        self.j, self.b = read(path)
        nm = [n.get("name") for n in self.j["nodes"]]
        self.to_skin = {i: skin.names.index(x) for i, x in enumerate(nm) if x in skin.names}

    def tracks(self, anim):
        out = {}
        for c in anim["channels"]:
            s = anim["samplers"][c["sampler"]]
            node = self.to_skin.get(c["target"]["node"])
            if node is not None:
                out[(node, c["target"]["path"])] = (acc(self.j, self.b, s["input"]).ravel().astype(float),
                                                     acc(self.j, self.b, s["output"]).astype(float), c)
        return out

    @staticmethod
    def at(tr, t):
        local = {}
        for key, (ti, v, _) in tr.items():
            ix = int(np.clip(np.searchsorted(ti, t, side="right") - 1, 0, len(ti) - 1))
            jx = min(ix + 1, len(ti) - 1)
            f = 0.0 if jx == ix else float(np.clip((t - ti[ix]) / (ti[jx] - ti[ix]), 0, 1))
            a, b = v[ix], v[jx]
            if key[1] == "rotation" and a @ b < 0:
                b = -b
            r = a * (1 - f) + b * f
            local[key] = r / np.linalg.norm(r) if key[1] == "rotation" else r
        return local

    def new_track(self, out):
        """A fresh accessor holding out (n x 4 float32) appended to the buffer."""
        j = self.j
        self.b += b"\0" * (-len(self.b) % 4)
        off = len(self.b)
        self.b += out.astype("<f4").tobytes()
        j["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": out.size * 4})
        j["accessors"].append({"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126, "count": len(out),
                               "type": "VEC4"})
        j["buffers"][0]["byteLength"] = len(self.b)
        return len(j["accessors"]) - 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mesh")
    ap.add_argument("pairs", nargs="+")
    ap.add_argument("--arms", default="L,R")
    ap.add_argument("--max-deg", type=float, default=30.0)
    ap.add_argument("--margin", type=float, default=0.003)
    ap.add_argument("--report")
    ap.add_argument("--clips", default="", help="only these clips (comma list); default every clip")
    a = ap.parse_args()
    skin = Skin(a.mesh)
    rows = []
    hips = skin.names.index("hips")
    pairs = list(zip(a.pairs[0::2], a.pairs[1::2]))
    clips = {}
    for side in a.arms.split(","):
        arm = skin.part["arm." + side]
        body = np.concatenate([skin.part[g] for g in BODY[side]])
        sh = skin.names.index("upper_arm." + side)
        Pb0, Nb0, _ = skin.pose({}, body)
        Pa0, _, _ = skin.pose({}, arm)
        bind = depth(Pa0, Pb0, Nb0)  # what already lies behind the body at rest is the mesh, not the clip
        idx = np.concatenate([arm, body])
        na = len(arm)
        for src, dst in pairs:
            cl = clips.setdefault(src, Clips(skin, src)) if src not in clips else clips[src]
            for anim in cl.j["animations"]:
                tr = cl.tracks(anim)
                if (sh, "rotation") not in tr or (a.clips and anim["name"] not in a.clips.split(",")):
                    continue
                times, quats, chan = tr[(sh, "rotation")]
                locals_ = [cl.at(tr, t) for t in times]
                for k in range(len(times)):
                    locals_[k][(sh, "rotation")] = quats[k] / np.linalg.norm(quats[k])

                def inside(k, phi, ang):
                    """Deepest arm vertex behind the body (m, over the bind) at key k swung ang degrees about phi."""
                    local = locals_[k]
                    if ang:
                        test = dict(local)
                        test[(sh, "rotation")] = swung(skin, local, sh, hips, phi, ang)
                        local = test
                    P, N, _ = skin.pose(local, idx)
                    return float(np.clip(depth(P[:na], P[na:], N[na:]) - bind, 0, None).max())

                def solve(k, phi):
                    for ang in range(1, int(a.max_deg) + 1):
                        if inside(k, phi, ang) <= a.margin:
                            return ang, True
                    return int(a.max_deg), False

                worst = np.array([inside(k, 0, 0) for k in range(len(times))])
                if worst.max() <= a.margin:
                    rows.append((src, anim["name"], side, "-", 0.0, worst.max() * 1000, worst.max() * 1000, 0))
                    continue
                kw = int(np.argmax(worst))
                # the swing direction: of 8 horizontal axes, the one that clears the worst key by the least angle
                tries = [(solve(kw, phi), phi) for phi in range(0, 360, 45)]
                phi = min(tries, key=lambda x: (not x[0][1], x[0][0] + AXIS_COST[x[1]], inside(kw, x[1], x[0][0])))[1]
                base = [dict(x) for x in locals_]

                def apply(phi):
                    """Swing every clipping key about phi, spread and blurred; the worst depth left (m) and the track."""
                    for k in range(len(times)):
                        locals_[k] = dict(base[k])
                    deg = np.array([solve(k, phi)[0] if worst[k] > a.margin else 0 for k in range(len(times))], float)
                    spread = np.array([deg[max(0, k - 2) : k + 3].max() for k in range(len(deg))])
                    blur = np.convolve(np.r_[spread[0], spread, spread[-1]], [0.25, 0.5, 0.25], "valid")
                    spread = np.maximum(blur, deg)
                    if abs(quats[0] @ quats[-1]) > 0.9999:  # a loop: same pose at both ends
                        spread[0] = spread[-1] = max(spread[0], spread[-1])
                    new = quats.copy()
                    for k in range(len(times)):
                        if spread[k] > 0:
                            new[k] = swung(skin, base[k], sh, hips, phi, spread[k])
                            locals_[k][(sh, "rotation")] = new[k]
                    return max(inside(k, 0, 0) for k in range(len(times))), new, spread

                after, new, spread = apply(phi)
                if after > a.margin:  # not clear: every other axis too, keep the best (never worse than the clip)
                    for p2 in range(0, 360, 45):
                        if p2 != phi:
                            r = apply(p2)
                            if r[0] < after:
                                after, new, spread, phi = r[0], r[1], r[2], p2
                if after >= worst.max():
                    rows.append((src, anim["name"], side, "-", 0.0, worst.max() * 1000, worst.max() * 1000, 0))
                    continue
                s = anim["samplers"][chan["sampler"]]
                anim["samplers"].append({"input": s["input"], "output": cl.new_track(new),
                                         "interpolation": s.get("interpolation", "LINEAR")})
                chan["sampler"] = len(anim["samplers"]) - 1
                rows.append((src, anim["name"], side, str(phi), float(spread.max()), worst.max() * 1000, after * 1000,
                             int((spread > 0).sum())))
    for src, dst in pairs:
        cl = clips[src]
        write(dst, cl.j, cl.b)
    lines = ["file\tclip\tarm\taxis\tmax_deg\tworst_mm_before\tworst_mm_after\tkeys"]
    lines += ["%s\t%s\t%s\t%s\t%.0f\t%.1f\t%.1f\t%d" % r for r in rows]
    if a.report:
        open(a.report, "w").write("\n".join(lines) + "\n")
    for r in lines:
        if r.split("\t")[3] != "-":
            print(r)


def swung(skin, local, sh, hips, phi, ang):
    """upper_arm's local rotation swung ang degrees about the horizontal axis phi degrees from the hips' front."""
    Wd = skin.world(local)
    fwd = Wd[hips][:3, :3] @ np.array([0.0, 0.0, 1.0])
    fwd[1] = 0.0
    fwd /= np.linalg.norm(fwd)
    side = np.cross(np.array([0.0, 1.0, 0.0]), fwd)
    ax = np.cos(np.radians(phi)) * fwd + np.sin(np.radians(phi)) * side
    pq = Wd[skin.parent[sh]][:3, :3]
    return rot_q(pq.T @ qmat(axis_q(ax, np.radians(ang))) @ pq, local[(sh, "rotation")])


def rot_q(R, q):
    """Quaternion of R @ mat(q)."""
    M = R @ qmat(q)
    w = np.sqrt(max(0.0, 1 + M[0, 0] + M[1, 1] + M[2, 2])) / 2
    x = np.sqrt(max(0.0, 1 + M[0, 0] - M[1, 1] - M[2, 2])) / 2
    y = np.sqrt(max(0.0, 1 - M[0, 0] + M[1, 1] - M[2, 2])) / 2
    z = np.sqrt(max(0.0, 1 - M[0, 0] - M[1, 1] + M[2, 2])) / 2
    x = np.copysign(x, M[2, 1] - M[1, 2])
    y = np.copysign(y, M[0, 2] - M[2, 0])
    z = np.copysign(z, M[1, 0] - M[0, 1])
    out = np.array([x, y, z, w])
    out /= np.linalg.norm(out)
    return out if out @ q >= 0 else -out


if __name__ == "__main__":
    main()
