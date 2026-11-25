"""rhand18.py IN OUT [cut=-0.025 roll=0]: replace Lace's right mitten with r17's Meshy porcelain fist (body-hand17 prim, mesh 1),
mirrored across x and aligned to the right forearm (mirrored LeftHand -> RightHand joint, mirrored left forearm axis -> right
forearm axis, optional extra roll in deg about the forearm). Body faces of the right hand past the wrist plane are dropped
(same rule as r17's left: hand/forearm-dominated verts beyond CUT m from the RightHand joint along the forearm).
New prim uses the same material (body-hand17) and texture; every vert rigid on RightHand."""
import sys
sys.path.insert(0, __file__.rsplit("/", 1)[0])
from glbio import *
from scipy.spatial.transform import Rotation as Rot
IN, OUT = sys.argv[1:3]
O = dict(a.split("=") for a in sys.argv[3:]); F = lambda k, d: float(O.get(k, d))
j, b = load(IN); N = j["nodes"]; sk = j["skins"][0]; names = [N[n]["name"] for n in sk["joints"]]
G = np.linalg.inv(acc(j, b, sk["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1))
jp = lambda n: G[names.index(n)][:3, 3]
iRH, iRF = names.index("RightHand"), names.index("RightForeArm")
wR = jp("RightHand"); fR = wR - jp("RightForeArm"); fR /= np.linalg.norm(fR)
wL = jp("LeftHand"); fL = wL - jp("LeftForeArm"); fL /= np.linalg.norm(fL)
mir = np.array([-1.0, 1, 1])
# 1. drop the right mitten
p = j["meshes"][1]["primitives"][2]; A = p["attributes"]
P = acc(j, b, A["POSITION"]).astype(float); J = acc(j, b, A["JOINTS_0"]); W = acc(j, b, A["WEIGHTS_0"]).astype(float)
Fb = acc(j, b, p["indices"]).reshape(-1, 3).astype(np.int64)
dom = J[np.arange(len(J)), W.argmax(1)]
R = [i for i, n in enumerate(names) if "RightHand" in n]
al = (P - wR) @ fR
cut = (np.isin(dom, R) | (dom == iRF)) & (al > F("cut", -0.025))
keepF = Fb[~cut[Fb].any(1)]
print("body: dropped faces", len(Fb) - len(keepF), "of", len(Fb))
ai = j["accessors"][p["indices"]]
b = replace_view(j, b, ai["bufferView"], keepF.astype(np.uint16 if ai["componentType"] == 5123 else np.uint32).ravel().tobytes())
ai["count"] = keepF.size; ai.pop("min", None); ai.pop("max", None)
# 2. mirrored r17 fist
hp = [q for q in j["meshes"][1]["primitives"] if j["materials"][q["material"]]["name"] == "body-hand17"][0]
H = acc(j, b, hp["attributes"]["POSITION"]).astype(float); HN = acc(j, b, hp["attributes"]["NORMAL"]).astype(float)
HF = acc(j, b, hp["indices"]).reshape(-1, 3)[:, ::-1]
Hm = (H - wL) * mir; HNm = HN * mir; fLm = fL * mir
v = np.cross(fLm, fR); s = np.linalg.norm(v); c = fLm @ fR
Ra = Rot.from_rotvec(v / s * np.arctan2(s, c)) if s > 1e-9 else Rot.identity()
Ra = Rot.from_rotvec(fR * np.radians(F("roll", 0))) * Ra
Q = Ra.apply(Hm) + wR; QN = Ra.apply(HNm)
print("align %.1f deg, roll %.0f; hand bbox" % (np.degrees(np.arctan2(s, c)), F("roll", 0)), Q.min(0).round(3), Q.max(0).round(3))
def addacc(arr, ct, typ, mm=False):
    global b
    raw = np.ascontiguousarray(arr.astype(CT[ct])).tobytes(); b.extend(b"\0" * ((-len(b)) % 4)); off = len(b); b.extend(raw)
    j["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": len(raw)})
    d = {"bufferView": len(j["bufferViews"]) - 1, "componentType": ct, "count": len(arr), "type": typ}
    if mm: d["min"] = [float(x) for x in arr.min(0)]; d["max"] = [float(x) for x in arr.max(0)]
    j["accessors"].append(d); return len(j["accessors"]) - 1
jt = j["accessors"][hp["attributes"]["JOINTS_0"]]["componentType"]
JJ = np.zeros((len(Q), 4)); JJ[:, 0] = iRH; WW = np.zeros((len(Q), 4)); WW[:, 0] = 1
prim = {"attributes": {"POSITION": addacc(Q, 5126, "VEC3", True), "NORMAL": addacc(QN, 5126, "VEC3"),
                       "TEXCOORD_0": hp["attributes"]["TEXCOORD_0"], "JOINTS_0": addacc(JJ, jt, "VEC4"), "WEIGHTS_0": addacc(WW, 5126, "VEC4")},
        "indices": addacc(HF.ravel(), j["accessors"][hp["indices"]]["componentType"], "SCALAR"), "material": hp["material"]}
j["meshes"][1]["primitives"].append(prim)
j["buffers"][0]["byteLength"] = len(b)
save(OUT, j, b); print("added hand tris", len(HF))
