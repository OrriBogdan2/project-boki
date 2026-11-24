# patchibm.py in.glb d.json out.glb [scale]: joints' inverse bind matrices get T(d): their skinned verts sit d further at rest
import sys, json, struct, numpy as np

sys.path.insert(0, "tools/art1/rig_test")
import gl

src, dj, out = sys.argv[1:4]
sc = float(sys.argv[4]) if len(sys.argv) > 4 else 1.0
js, b = gl.read(src)
dd = json.load(open(dj))
d = np.array(dd["d_gltf"]) * sc
sk = js["skins"][0]
nodes = js["nodes"]
jn = [nodes[j]["name"] for j in sk["joints"]]
a = js["accessors"][sk["inverseBindMatrices"]]
v = js["bufferViews"][a["bufferView"]]
off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
M = (
    np.frombuffer(bytes(b[off : off + a["count"] * 64]), np.float32).reshape(-1, 4, 4).copy()
)  # column-major: M[i].T is the matrix
for nm in dd["joints"]:
    i = jn.index(nm)
    m = M[i].T.astype(np.float64)
    T = np.eye(4)
    T[:3, 3] = d
    M[i] = (m @ T).T.astype(np.float32)
b[off : off + a["count"] * 64] = M.tobytes()
jb = json.dumps(js, separators=(",", ":")).encode()
jb += b" " * ((4 - len(jb) % 4) % 4)
bb = bytes(b)
bb += b"\0" * ((4 - len(bb) % 4) % 4)
open(out, "wb").write(
    b"glTF"
    + struct.pack("<II", 2, 12 + 8 + len(jb) + 8 + len(bb))
    + struct.pack("<I", len(jb))
    + b"JSON"
    + jb
    + struct.pack("<I", len(bb))
    + b"BIN\0"
    + bb
)
print("ibm patched", out, len(dd["joints"]), "joints")
