"""keyfix18.py IN OUT [d=0.05 near=0.25 far=0.12]: Attack only. Rotate RightArm keys about the shoulder so the draw hand moves D m
horizontally away from the head (weight = smoothstep by hand-head distance: 1 below FAR, 0 above NEAR). StringMid translation
keys follow the hand by the same world shift (scaled by the string's draw weight), so the string stays in the draw hand."""
import sys
sys.path.insert(0, __file__.rsplit("/", 1)[0])
from fk import *
IN, OUT = sys.argv[1:3]
O = dict(a.split("=") for a in sys.argv[3:]); F = lambda k, d: float(O.get(k, d))
D, NEAR, FAR = F("d", 0.05), F("near", 0.25), F("far", 0.12)
j, b = load(IN); N = j["nodes"]; idx = {n.get("name"): i for i, n in enumerate(N) if "mesh" not in n}
par = {c: i for i, n in enumerate(N) for c in n.get("children", [])}
an = [a for a in j["animations"] if a["name"] == "Attack"][0]
ch = {(c["target"]["node"], c["target"]["path"]): c for c in an["channels"]}
iA, iSM = idx["RightArm"], idx["StringMid"]
cA = ch[(iA, "rotation")]; sA = an["samplers"][cA["sampler"]]
tA = acc(j, b, sA["input"])[:, 0]; qA = acc(j, b, sA["output"]).astype(float)
f0 = fk(IN, "Attack", tA, ["RightArm", "RightHand", "Head", "StringMid", "Bow"])
nq = qA.copy(); shift = {}
for k, t in enumerate(tA):
    sh = f0[(t, "RightArm")][:3, 3]; rh = f0[(t, "RightHand")][:3, 3]; hd = f0[(t, "Head")][:3, 3]
    dist = np.linalg.norm(rh - hd); x = np.clip((NEAR - dist) / (NEAR - FAR), 0, 1); w = x * x * (3 - 2 * x)
    if w <= 0: shift[t] = np.zeros(3); continue
    dirh = rh - hd; dirh[1] = 0; dirh /= np.linalg.norm(dirh)
    arm = rh - sh; L = np.linalg.norm(arm)
    ax = np.cross(arm, dirh); ax /= np.linalg.norm(ax)
    R = Rot.from_rotvec(ax * (D * w / L))
    Pw = Rot.from_matrix(f0[(t, "RightArm")][:3, :3]) * Rot.from_quat(qA[k]).inv()  # parent world rotation
    nq[k] = (Pw.inv() * R * Pw * Rot.from_quat(qA[k])).as_quat()
    shift[t] = R.apply(rh - sh) + sh - rh
def newacc(arr, typ):
    global b
    raw = np.ascontiguousarray(np.asarray(arr, np.float32)).tobytes(); b.extend(b"\0" * ((-len(b)) % 4)); off = len(b); b.extend(raw)
    j["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": len(raw)})
    j["accessors"].append({"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126, "count": len(arr), "type": typ}); return len(j["accessors"]) - 1
an["samplers"].append({"input": sA["input"], "output": newacc(nq, "VEC4"), "interpolation": sA.get("interpolation", "LINEAR")}); cA["sampler"] = len(an["samplers"]) - 1
# string follows the hand
cS = ch[(iSM, "translation")]; sS = an["samplers"][cS["sampler"]]; tS = acc(j, b, sS["input"])[:, 0]; oS = acc(j, b, sS["output"]).astype(float)
fS = fk(IN, "Attack", tS, ["StringMid", "Bow"])
shx = np.array([[np.interp(t, tA, [shift[u][c] for u in tA]) for c in range(3)] for t in tS])
nS = oS.copy()
for k, t in enumerate(tS):
    Mb = fS[(t, "Bow")]; pw = fS[(t, "StringMid")][:3, 3] + shx[k]
    # StringMid parent = Bow bone: local = Bow^-1 * world (translation only)
    Mp = fS[(t, "Bow")] if par.get(iSM) == idx["Bow"] else None
    nS[k] = (np.linalg.inv(Mp) @ np.r_[pw, 1])[:3] if Mp is not None else oS[k] + shx[k]
an["samplers"].append({"input": sS["input"], "output": newacc(nS, "VEC3"), "interpolation": sS.get("interpolation", "LINEAR")}); cS["sampler"] = len(an["samplers"]) - 1
j["buffers"][0]["byteLength"] = len(b)
save(OUT, j, b)
f1 = fk(OUT, "Attack", tA, ["RightHand", "Head", "StringMid"])
print("StringMid parent is Bow:", par.get(iSM) == idx["Bow"])
for t in tA[::2]:
    d0 = np.linalg.norm(f0[(t, "RightHand")][:3, 3] - f0[(t, "Head")][:3, 3]) * 100; d1 = np.linalg.norm(f1[(t, "RightHand")][:3, 3] - f1[(t, "Head")][:3, 3]) * 100
    s0 = np.linalg.norm(f0[(t, "RightHand")][:3, 3] - f0[(t, "StringMid")][:3, 3]) * 100; s1 = np.linalg.norm(f1[(t, "RightHand")][:3, 3] - f1[(t, "StringMid")][:3, 3]) * 100
    if d0 < 30: print("t%.2f RH-head %.1f -> %.1f cm | RH-string %.1f -> %.1f" % (t, d0, d1, s0, s1))
