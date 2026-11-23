"""Per-frame skinned-edge stretch of a .glb (CPU linear blend skinning, numpy). Tear/spike proxy:
an edge whose length vs bind exceeds RATIO is a tear/spike. Per clip frame: share of edges over RATIO, and per body region.
usage: glbstretch.py OUT.json GLB [clip,clip...] [--fps 15] [--map name=clip,...]
Regions by bind-pose height fraction (feet 0 .. crown 1) and lateral distance from the body axis."""

import json
import struct
import sys
import numpy as np

RATIO = 3.0
CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def load(p):
    b = open(p, "rb").read()
    l, _ = struct.unpack("<II", b[12:20])
    j = json.loads(b[20 : 20 + l])
    o = 20 + l
    bl, _ = struct.unpack("<II", b[o : o + 8])
    return j, b[o + 8 : o + 8 + bl]


def acc(j, bin_, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    n, k = a["count"], NC[a["type"]]
    dt = np.dtype(CT[a["componentType"]])
    st = bv.get("byteStride")
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    if st and st != dt.itemsize * k:
        x = (
            np.lib.stride_tricks.as_strided(
                np.frombuffer(bin_, np.uint8, offset=off, count=(n - 1) * st + dt.itemsize * k),
                shape=(n, k * dt.itemsize),
                strides=(st, 1),
            )
            .copy()
            .view(dt)
            .reshape(n, k)
        )
    else:
        x = np.frombuffer(bin_, dt, n * k, off).reshape(n, k).copy()
    if a.get("normalized"):
        x = x.astype(np.float64) / np.iinfo(dt).max if dt.kind in "ui" else x
    return x


def q2m(q):
    x, y, z, w = q
    return np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ]
    )


def local(n, o):
    T = o.get("translation", n.get("translation", [0, 0, 0]))
    R = o.get("rotation", n.get("rotation", [0, 0, 0, 1]))
    S = o.get("scale", n.get("scale", [1, 1, 1]))
    M = np.eye(4)
    if "matrix" in n and not o and "translation" not in n:
        return np.array(n["matrix"]).reshape(4, 4).T
    M[:3, :3] = q2m(R) * np.array(S)[None, :]
    M[:3, 3] = T
    return M


def slerp(a, b, t):
    d = float(np.dot(a, b))
    if d < 0:
        b, d = -b, -d
    if d > 0.9995:
        r = a + (b - a) * t
    else:
        th = np.arccos(d)
        r = (np.sin((1 - t) * th) * a + np.sin(t * th) * b) / np.sin(th)
    return r / np.linalg.norm(r)


class Model:
    def __init__(self, p):
        self.j, self.b = load(p)
        j, b = self.j, self.b
        self.nodes = j["nodes"]
        self.par = {c: i for i, n in enumerate(self.nodes) for c in n.get("children", [])}
        skin_nodes = [n for n in self.nodes if "mesh" in n and "skin" in n]
        sk = j["skins"][skin_nodes[0]["skin"]]
        self.joints = sk["joints"]
        self.names = [self.nodes[i]["name"] for i in self.joints]
        self.ibm = acc(j, b, sk["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
        Ps, Is, Js, Ws, off = [], [], [], [], 0
        for n in skin_nodes:
            if j["skins"][n["skin"]]["joints"] != self.joints:
                continue
            for pr in j["meshes"][n["mesh"]]["primitives"]:
                a = pr["attributes"]
                P = acc(j, b, a["POSITION"]).astype(np.float64)
                Ps.append(P)
                Is.append(acc(j, b, pr["indices"]).ravel().astype(np.int64) + off)
                Js.append(acc(j, b, a["JOINTS_0"]).astype(int))
                w = acc(j, b, a["WEIGHTS_0"]).astype(np.float64)
                Ws.append(w)
                off += len(P)
        self.P = np.concatenate(Ps)
        self.I = np.concatenate(Is).reshape(-1, 3)
        self.J = np.concatenate(Js)
        W = np.concatenate(Ws)
        self.W = W / np.maximum(W.sum(1, keepdims=True), 1e-9)
        self.tris = len(self.I)
        # unique edges
        e = np.concatenate([self.I[:, [0, 1]], self.I[:, [1, 2]], self.I[:, [2, 0]]])
        e.sort(1)
        self.E = np.unique(e, axis=0)
        # bind pose through the skin (skinned bind may differ from raw positions by a node transform)
        self.bind = self.skin({})
        d = np.linalg.norm(self.bind[self.E[:, 0]] - self.bind[self.E[:, 1]], axis=1)
        self.rest = d
        self.ok = d > 0.004
        y = self.bind[:, 1]
        self.y0, self.y1 = float(y.min()), float(y.max())
        self.height = self.y1 - self.y0
        self.cache = {}

    def anims(self):
        return {a.get("name", str(i)): a for i, a in enumerate(self.j.get("animations", []))}

    def sample(self, an, t):
        out = {}
        for ch in an["channels"]:
            n = ch["target"].get("node")
            if n is None:
                continue
            s = an["samplers"][ch["sampler"]]
            key = (id(an), ch["sampler"])
            if key not in self.cache:
                self.cache[key] = (acc(self.j, self.b, s["input"]).ravel(), acc(self.j, self.b, s["output"]))
            ti, v = self.cache[key]
            if s.get("interpolation") == "CUBICSPLINE":
                v = v[1::3]
            k = np.searchsorted(ti, t, side="right") - 1
            if k < 0:
                val = v[0]
            elif k >= len(ti) - 1:
                val = v[-1]
            else:
                u = (t - ti[k]) / (ti[k + 1] - ti[k]) if ti[k + 1] > ti[k] else 0
                val = slerp(v[k], v[k + 1], u) if ch["target"]["path"] == "rotation" else v[k] * (1 - u) + v[k + 1] * u
            out.setdefault(n, {})[ch["target"]["path"]] = val
        return out

    def skin(self, over):
        mats = {}

        def get(i):
            if i in mats:
                return mats[i]
            M = local(self.nodes[i], over.get(i, {}))
            mats[i] = (get(self.par[i]) @ M) if i in self.par else M
            return mats[i]

        SM = np.stack([get(jn) @ self.ibm[k] for k, jn in enumerate(self.joints)])
        Ph = np.concatenate([self.P, np.ones((len(self.P), 1))], 1)
        out = np.zeros((len(self.P), 3))
        for k in range(4):
            out += self.W[:, k : k + 1] * np.einsum("nij,nj->ni", SM[self.J[:, k]], Ph)[:, :3]
        return out

    def duration(self, an):
        return max(float(self.j["accessors"][s["input"]]["max"][0]) for s in an["samplers"])

    def ratios(self, X):
        d = np.linalg.norm(X[self.E[:, 0]] - X[self.E[:, 1]], axis=1)
        return d / np.maximum(self.rest, 1e-4)

    def lengths(self, X):
        return np.linalg.norm(X[self.E[:, 0]] - X[self.E[:, 1]], axis=1)


REG = ["head", "hands", "arms_shoulders", "torso", "hips_crotch", "legs", "feet"]


def regions(m):
    """Region id per vertex from the bind pose (his front is +Z or +Y per file; use only y and |x|)."""
    y = (m.bind[:, 1] - m.y0) / m.height
    ax = np.abs(m.bind[:, 0] - np.median(m.bind[:, 0]))
    r = np.full(len(y), 3)
    r[y > 0.82] = 0  # head (helmet) top 18%
    r[(y <= 0.82) & (y > 0.5)] = 3  # torso
    r[(y <= 0.52) & (y > 0.40)] = 4  # hips/crotch band
    r[(y <= 0.40) & (y > 0.07)] = 5  # legs
    r[y <= 0.07] = 6  # feet
    arm = (ax > 0.30 * m.height * 0.5 * 1.0 + 0.16) & (y > 0.40) & (y <= 0.82)
    r[arm] = 2
    hand = (ax > 0.62 * (m.height * 0.5)) & (y > 0.30) & (y <= 0.62)
    r[hand] = 1
    return r


def run(path, clips, fps=15.0, names=None):
    m = Model(path)
    reg = regions(m)
    ereg = reg[m.E[:, 0]]
    res = {"file": path, "tris": int(m.tris), "verts": int(len(m.P)), "height": m.height, "clips": {}}
    an = m.anims()
    for nm in clips or list(an):
        if nm not in an:
            continue
        a = an[nm]
        dur = m.duration(a)
        n = max(2, int(dur * fps))
        fr = []
        for i in range(n):
            X = m.skin(m.sample(a, min(i / fps, dur - 1e-4)))
            r = m.ratios(X)
            bad = (r > RATIO) & m.ok
            spike = bad & (
                m.lengths(X) > 0.06 * m.height
            )  # stretched past 3x AND longer than 6% of his height: a visible spike/tear
            row = {
                "spike": int(spike.sum()),
                "spike_reg": [int((spike & (ereg == k)).sum()) for k in range(len(REG))],
                "edges": int(m.ok.sum()),
                "bad_pct": 100.0 * bad.sum() / max(m.ok.sum(), 1),
                "bad": int(bad.sum()),
                "max": float(r[m.ok].max()),
            }
            row["reg"] = [int((bad & (ereg == k)).sum()) for k in range(len(REG))]
            fr.append(row)
        res["clips"][nm] = {"frames": n, "dur": dur, "rows": fr}
    return res


if __name__ == "__main__":
    out, p = sys.argv[1], sys.argv[2]
    clips = sys.argv[3].split(",") if len(sys.argv) > 3 and not sys.argv[3].startswith("--") else None
    r = run(p, clips)
    json.dump(r, open(out, "w"))
    print(p, "tris", r["tris"], "height %.2f" % r["height"])
    for nm, c in r["clips"].items():
        rows = c["rows"]
        flag = sum(1 for x in rows if x["spike"] >= 10)
        print(
            "  %-20s frames %3d  frames with >=10 spike edges: %3d (%.0f%%)  worst %.1fx  max spike edges %d"
            % (
                nm,
                c["frames"],
                flag,
                100 * flag / c["frames"],
                max(x["max"] for x in rows),
                max(x["spike"] for x in rows),
            )
        )
