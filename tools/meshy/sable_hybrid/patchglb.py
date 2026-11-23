"""patchglb.py IN.glb OUT.glb : apply fixrule to JOINTS_0/WEIGHTS_0 bytes in place; all other bytes identical."""

import sys, struct, numpy as np

sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
import glbstretch as g, fixrule

src, dst = sys.argv[1], sys.argv[2]
m = g.Model(src)
raw = bytearray(open(src, "rb").read())
jl, _ = struct.unpack("<II", raw[12:20])
binoff = 20 + jl + 8
J, W, st = fixrule.run(m.J, m.W, m.bind, m.names, m.E)
print(st)
a = [
    pr["attributes"]
    for n in m.j["nodes"]
    if "skin" in n and "mesh" in n
    for pr in m.j["meshes"][n["mesh"]]["primitives"]
]
base = 0
for at in a:
    cnt = m.j["accessors"][at["POSITION"]]["count"]
    for key, arr in (("JOINTS_0", J[base : base + cnt]), ("WEIGHTS_0", W[base : base + cnt])):
        ac = m.j["accessors"][at[key]]
        bv = m.j["bufferViews"][ac["bufferView"]]
        dt = np.dtype(g.CT[ac["componentType"]])
        off = binoff + bv.get("byteOffset", 0) + ac.get("byteOffset", 0)
        st_ = bv.get("byteStride") or dt.itemsize * 4
        assert ac["count"] == cnt and (dt != np.uint8 or arr.max() < 256) and not ac.get("normalized")
        x = np.ascontiguousarray(arr.astype(dt)).view(np.uint8).reshape(cnt, -1)
        n = (cnt - 1) * st_ + dt.itemsize * 4
        buf = np.frombuffer(bytes(raw[off : off + n]), np.uint8).copy()
        np.lib.stride_tricks.as_strided(buf, shape=(cnt, dt.itemsize * 4), strides=(st_, 1))[:] = x
        raw[off : off + n] = buf.tobytes()
    base += cnt
assert base == len(J)
open(dst, "wb").write(raw)
m2 = g.Model(dst)
print("verify J", np.array_equal(m2.J, J.astype(int)), "W", np.allclose(m2.W, W, atol=1e-6), "json same", m2.j == m.j)
