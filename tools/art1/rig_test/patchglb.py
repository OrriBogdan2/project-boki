# plain python (numpy): patchglb.py in.glb weights.npz out.glb meshname
import sys, numpy as np, struct, json

sys.path.insert(0, "tools/art1/rig_test")
import gl

src, npz, out, mname = sys.argv[1:5]
js, b = gl.read(src)
d = np.load(npz)
names = list(d["names"])
W = d["W"]
P = d["P"]
nodes = js["nodes"]
sk = js["skins"][0]
jn = [nodes[j]["name"] for j in sk["joints"]]
col = [jn.index(nm) if nm in jn else None for nm in names]
assert all(c is not None for c in col), [n for n, c in zip(names, col) if c is None]
acc = js["accessors"]
bv = js["bufferViews"]


def view(ai, dt, nc):
    a = acc[ai]
    v = bv[a["bufferView"]]
    st = v.get("byteStride") or np.dtype(dt).itemsize * nc
    off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    return a["count"], off, st


from scipy.spatial import cKDTree

tree = cKDTree(np.stack([P[:, 0], P[:, 2], -P[:, 1]], 1))


def nverts(m):
    return sum(acc[p["attributes"]["POSITION"]]["count"] for p in m["primitives"] if "JOINTS_0" in p["attributes"])


mesh = max(js["meshes"], key=nverts)
i = 0
for p in mesh["primitives"]:
    at = p["attributes"]
    cnt, po, ps = view(at["POSITION"], np.float32, 3)
    pos = np.stack([np.frombuffer(b, np.float32, 3, po + k * ps) for k in range(cnt)])
    # blender (x,y,z) <- gltf (x,-z,y)
    dist, ix = tree.query(pos)
    assert dist.max() < 2e-4, ("no position match", dist.max())
    _, jo, js_ = view(at["JOINTS_0"], np.uint8, 4)
    _, wo, ws = view(at["WEIGHTS_0"], np.float32, 4)
    Wp = W[ix]
    idx = np.argsort(-Wp, axis=1)[:, :4]
    ww = np.take_along_axis(Wp, idx, 1)
    ww = ww / np.maximum(ww.sum(1, keepdims=True), 1e-9)
    for k in range(cnt):
        for q in range(4):
            b[jo + k * js_ + q] = col[idx[k, q]] if ww[k, q] > 0 else 0
        b[wo + k * ws : wo + k * ws + 16] = ww[k].astype(np.float32).tobytes()
    i += cnt
print("mesh", mesh["name"], "prims", len(mesh["primitives"]))
# write
jb = json.dumps(js, separators=(",", ":")).encode()
jb += b" " * ((4 - len(jb) % 4) % 4)
bb = bytes(b)
bb += b"\0" * ((4 - len(bb) % 4) % 4)
with open(out, "wb") as f:
    f.write(b"glTF" + struct.pack("<II", 2, 12 + 8 + len(jb) + 8 + len(bb)))
    f.write(struct.pack("<I", len(jb)) + b"JSON" + jb)
    f.write(struct.pack("<I", len(bb)) + b"BIN\0" + bb)
print("patched", out, i, "verts")
