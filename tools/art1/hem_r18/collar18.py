"""collar18.py IN OUT [y=1.012 tin=0.005 tout=0.006]: close the waist well (hem.md D2): a wine annulus (skirt-liner material and texel)
at height Y from just inside the body (corset/peplum outer radius - TIN) to just inside the skirt rim (rim inner radius + TOUT),
per 7.5 deg; rigid on Hips like the skirt waist band. Body and skirt bytes untouched; new prim in Mesh_0."""
import sys
sys.path.insert(0, __file__.rsplit("/", 1)[0])
from glbio import *
IN, OUT = sys.argv[1:3]
O = dict(a.split("=") for a in sys.argv[3:]); F = lambda k, d: float(O.get(k, d))
j, b = load(IN); sk = j["skins"][0]; N = j["nodes"]; names = [N[k]["name"] for k in sk["joints"]]
bd = j["meshes"][1]["primitives"][2]; B = acc(j, b, bd["attributes"]["POSITION"]).astype(float)
BJ = acc(j, b, bd["attributes"]["JOINTS_0"]); BW = acc(j, b, bd["attributes"]["WEIGHTS_0"])
dom = np.array(names)[BJ[np.arange(len(BJ)), BW.argmax(1)]]
core = ~np.array([("Arm" in d) or ("Hand" in d) or ("Shoulder" in d) for d in dom])
sp = j["meshes"][4]["primitives"][0]; S = acc(j, b, sp["attributes"]["POSITION"]).astype(float)
lin = [p for p in j["meshes"][4]["primitives"] if j["materials"][p["material"]]["name"] == "skirt-liner"][0]
uv = acc(j, b, lin["attributes"]["TEXCOORD_0"])[0]
Y = F("y", 1.012); c = np.median(B[core & (B[:, 1] > 0.98) & (B[:, 1] < 1.04)][:, [0, 2]], 0)
NA = 48; ang = np.linspace(-np.pi, np.pi, NA, endpoint=False)
def prof(P, y0, y1, f, fill):
    Q = P[(P[:, 1] >= y0) & (P[:, 1] <= y1)]; a = np.arctan2(Q[:, 2] - c[1], Q[:, 0] - c[0]); r = np.hypot(Q[:, 0] - c[0], Q[:, 2] - c[1])
    k = ((a + np.pi) / (2 * np.pi) * NA).astype(int) % NA
    R = np.array([f(r[np.abs(((k - i + NA // 2) % NA) - NA // 2) <= 1]) if (np.abs(((k - i + NA // 2) % NA) - NA // 2) <= 1).any() else np.nan for i in range(NA)])
    ok = ~np.isnan(R); return np.interp(np.arange(NA), np.arange(NA)[ok], R[ok], period=NA)
rb = prof(B[core], Y - 0.012, Y + 0.008, lambda r: np.percentile(r, 90), 1) - F("tin", 0.005)
rs = prof(S, Y - 0.008, Y + 0.012, np.min, 1) + F("tout", 0.006)
rs = np.maximum(rs, rb + 0.004)
print("collar width cm min/med/max", np.round(np.percentile((rs - rb) * 100, [0, 50, 100]), 1))
rings = [np.stack([c[0] + r * np.cos(ang), np.full(NA, Y), c[1] + r * np.sin(ang)], 1) for r in (rb, (rb + rs) / 2, rs)]
V = np.concatenate(rings); Fs = []
for r in range(2):
    for i in range(NA):
        a0, c0, d0, e0 = r * NA + i, r * NA + (i + 1) % NA, (r + 1) * NA + i, (r + 1) * NA + (i + 1) % NA
        Fs += [[a0, d0, c0], [c0, d0, e0]]
Fa = np.array(Fs)
nr = np.cross(V[Fa[:, 1]] - V[Fa[:, 0]], V[Fa[:, 2]] - V[Fa[:, 0]])
if nr[:, 1].sum() < 0: Fa = Fa[:, [0, 2, 1]]
iH = names.index("Hips")
def addacc(arr, ct, typ, target=None, mm=False):
    global b
    raw = np.ascontiguousarray(arr).tobytes(); b.extend(b"\0" * ((-len(b)) % 4)); o = len(b); b.extend(raw)
    bv = {"buffer": 0, "byteOffset": o, "byteLength": len(raw)}
    if target: bv["target"] = target
    j["bufferViews"].append(bv)
    a = {"bufferView": len(j["bufferViews"]) - 1, "componentType": ct, "count": len(arr), "type": typ}
    if mm: a["min"] = [float(x) for x in arr.min(0)]; a["max"] = [float(x) for x in arr.max(0)]
    j["accessors"].append(a); return len(j["accessors"]) - 1
Jn = np.zeros((len(V), 4), int); Jn[:, 0] = iH; W = np.zeros((len(V), 4)); W[:, 0] = 1
nm = np.tile([0, 1.0, 0], (len(V), 1))
at = {"POSITION": addacc(V.astype(np.float32), 5126, "VEC3", 34962, True), "NORMAL": addacc(nm.astype(np.float32), 5126, "VEC3", 34962),
      "TEXCOORD_0": addacc(np.tile(uv, (len(V), 1)).astype(np.float32), 5126, "VEC2", 34962),
      "JOINTS_0": addacc(Jn.astype(np.uint8), 5121, "VEC4", 34962), "WEIGHTS_0": addacc(W.astype(np.float32), 5126, "VEC4", 34962)}
j["meshes"][4]["primitives"].append({"attributes": at, "indices": addacc(Fa.astype(np.uint16).ravel(), 5123, "SCALAR", 34963), "material": lin["material"]})
j["buffers"][0]["byteLength"] = len(b); save(OUT, j, b); print("added tris", len(Fa))
