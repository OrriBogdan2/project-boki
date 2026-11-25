"""legfill18.py IN OUT [k=0.86 yt=0.75 yb=0.40 hp=handpts.npz hgap=0.006 rmin=0.35] (hp: carve the tube off hand/bow points, r16 rule): inner porcelain leg tubes (thigh-liner material, its single porcelain texel)
inside the Meshy body's thighs/knees/boot tops, so the body's holes show porcelain, not the dark inside (hem.md D1 / D6).
Rigid on UpLeg above y 0.60, blend to Leg over 0.60..0.54, rigid on Leg below. Body mesh bytes untouched; new prim in Mesh_0."""
import sys
sys.path.insert(0, __file__.rsplit("/", 1)[0])
from glbio import *
IN, OUT = sys.argv[1:3]
O = dict(a.split("=") for a in sys.argv[3:])
F = lambda k, d: float(O.get(k, d))
j, b = load(IN)
N = j["nodes"]; sk = j["skins"][0]; names = [N[k]["name"] for k in sk["joints"]]
bd = j["meshes"][1]["primitives"][2]
B = acc(j, b, bd["attributes"]["POSITION"]).astype(float)
BJ = acc(j, b, bd["attributes"]["JOINTS_0"]); BW = acc(j, b, bd["attributes"]["WEIGHTS_0"])
dom = np.array(names)[BJ[np.arange(len(BJ)), BW.argmax(1)]]
lin = [p for p in j["meshes"][4]["primitives"] if j["materials"][p["material"]]["name"] == "thigh-liner"][0]
uvw = acc(j, b, lin["attributes"]["TEXCOORD_0"])[0]
NA = 40; ang = np.linspace(-np.pi, np.pi, NA, endpoint=False)
HP = dict(np.load(O["hp"])) if "hp" in O else None
K, YT, YB = F("k", 0.86), F("yt", 0.75), F("yb", 0.40)
ys = np.round(np.arange(YT, YB - 1e-6, -0.015), 4)
allV, allF, allJ, allW = [], [], [], []
for side in ("Left", "Right"):
    iu, il = names.index(side + "UpLeg"), names.index(side + "Leg")
    legm = np.isin(dom, [side + "UpLeg", side + "Leg"])
    rings = []
    for y in ys:
        Q = B[legm & (np.abs(B[:, 1] - y) < 0.012)]
        c = np.median(Q[:, [0, 2]], 0)
        a = np.arctan2(Q[:, 2] - c[1], Q[:, 0] - c[0]); r = np.hypot(Q[:, 0] - c[0], Q[:, 2] - c[1])
        kk = ((a + np.pi) / (2 * np.pi) * NA).astype(int) % NA
        R = np.full(NA, np.nan)
        for i in range(NA):
            m = np.abs(((kk - i + NA // 2) % NA) - NA // 2) <= 1
            if m.any(): R[i] = np.percentile(r[m], 90)
        ok = ~np.isnan(R)
        R = np.interp(np.arange(NA), np.arange(NA)[ok], R[ok], period=NA)
        R = np.minimum(R, np.median(R) * 1.2)
        for _ in range(2): R = (np.roll(R, 1) + 2 * R + np.roll(R, -1)) / 4
        R = R * K
        if HP is not None:
            Qh = HP[side[0]][np.abs(HP[side[0]][:, 1] - y) < F("yw", 0.02)] if y >= 0.54 else np.zeros((0, 3))
            if y < 0.62: Qh = np.vstack([Qh, HP[side[0] + "L"][np.abs(HP[side[0] + "L"][:, 1] - y) < F("yw", 0.02)]])
            if len(Qh):
                qa = np.arctan2(Qh[:, 2] - c[1], Qh[:, 0] - c[0]); qr = np.hypot(Qh[:, 0] - c[0], Qh[:, 2] - c[1])
                da = np.abs((qa[None, :] - ang[:, None] + np.pi) % (2 * np.pi) - np.pi) < np.radians(F("aw", 20))
                lim = np.where(da, qr[None, :], 9).min(1) - F("hgap", 0.006)
                for _ in range(2): lim = np.minimum(lim, np.minimum(np.roll(lim, 1), np.roll(lim, -1)) + 0.004)
                R = np.maximum(np.minimum(R, lim), R * F("rmin", 0.35))
        rings.append((c, R))
    # smooth centres/radii along y
    C = np.array([r[0] for r in rings]); RR = np.array([r[1] for r in rings])
    for _ in range(0 if HP is not None else 2):
        C[1:-1] = (C[:-2] + 2 * C[1:-1] + C[2:]) / 4; RR[1:-1] = (RR[:-2] + 2 * RR[1:-1] + RR[2:]) / 4
    V = np.concatenate([np.stack([C[r, 0] + RR[r] * np.cos(ang), np.full(NA, ys[r]), C[r, 1] + RR[r] * np.sin(ang)], 1) for r in range(len(ys))])
    Fs = []
    for r in range(len(ys) - 1):
        for i in range(NA):
            a0, c0, d0, e0 = r * NA + i, r * NA + (i + 1) % NA, (r + 1) * NA + i, (r + 1) * NA + (i + 1) % NA
            Fs += [[a0, d0, c0], [c0, d0, e0]]
    Fa = np.array(Fs)
    nr = np.cross(V[Fa[:, 1]] - V[Fa[:, 0]], V[Fa[:, 2]] - V[Fa[:, 0]])
    cen = np.repeat(np.c_[C[:, 0], ys, C[:, 1]], NA, 0)
    if (nr * (V[Fa].mean(1) - cen[Fa[:, 0]])).sum() < 0: Fa = Fa[:, [0, 2, 1]]
    t = np.clip((V[:, 1] - 0.54) / 0.06, 0, 1); t = t * t * (3 - 2 * t)
    Jn = np.zeros((len(V), 4), int); Jn[:, 0] = iu; Jn[:, 1] = il
    W = np.zeros((len(V), 4)); W[:, 0] = t; W[:, 1] = 1 - t
    allF.append(Fa + sum(len(v) for v in allV)); allV.append(V); allJ.append(Jn); allW.append(W)
    print(side, "rings", len(ys), "r min/max", RR.min().round(3), RR.max().round(3))
V = np.vstack(allV); Fa = np.vstack(allF); Jn = np.vstack(allJ); W = np.vstack(allW)
def addacc(arr, ct, typ, target=None, mm=False):
    global b
    raw = np.ascontiguousarray(arr).tobytes(); b.extend(b"\0" * ((-len(b)) % 4)); o = len(b); b.extend(raw)
    bv = {"buffer": 0, "byteOffset": o, "byteLength": len(raw)}
    if target: bv["target"] = target
    j["bufferViews"].append(bv)
    a = {"bufferView": len(j["bufferViews"]) - 1, "componentType": ct, "count": len(arr), "type": typ}
    if mm: a["min"] = [float(x) for x in arr.min(0)]; a["max"] = [float(x) for x in arr.max(0)]
    j["accessors"].append(a); return len(j["accessors"]) - 1
n = np.zeros_like(V); fn = np.cross(V[Fa[:, 1]] - V[Fa[:, 0]], V[Fa[:, 2]] - V[Fa[:, 0]])
for k in range(3): np.add.at(n, Fa[:, k], fn)
n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
at = {"POSITION": addacc(V.astype(np.float32), 5126, "VEC3", 34962, True), "NORMAL": addacc(n.astype(np.float32), 5126, "VEC3", 34962),
      "TEXCOORD_0": addacc(np.tile(uvw, (len(V), 1)).astype(np.float32), 5126, "VEC2", 34962),
      "JOINTS_0": addacc(Jn.astype(np.uint8), 5121, "VEC4", 34962), "WEIGHTS_0": addacc(W.astype(np.float32), 5126, "VEC4", 34962)}
j["meshes"][4]["primitives"].append({"attributes": at, "indices": addacc(Fa.astype(np.uint16).ravel(), 5123, "SCALAR", 34963), "material": lin["material"]})
j["buffers"][0]["byteLength"] = len(b)
print("added tris", len(Fa), "verts", len(V))
save(OUT, j, b)
