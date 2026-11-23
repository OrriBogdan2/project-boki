"""chainhang.py (r2, from r1 tailhang.py) IN.glb OUT.glb [K=1.0] : bake a gravity hang + thigh/floor collision into the rotation keys of Meshy's
own coat-tail ROOT bones (Bone_008/012/016/020, children of Hips). Variant C of the Sable hybrid rig.
Only animation sampler outputs of those 4 bones change (new accessors appended). nodes/skins/meshes/materials untouched.
Hang: tail world direction = rest direction turned only by the hips' yaw (pelvis pitch/roll removed), blended by K
with Meshy's pinned direction; then pushed out of the thigh/shin capsules and kept above the floor; light time smoothing."""

import sys, json, struct, numpy as np

sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
import glbstretch as g

IN, OUT = sys.argv[1:3]
K = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0
ROOTS = ["Bone_009", "Bone_013"]
m = g.Model(IN)
j = m.j
N = j["nodes"]
nid = {n["name"]: i for i, n in enumerate(N)}
par = m.par


def glob(over):
    G = {}

    def f(i):
        if i not in G:
            L = g.local(N[i], over.get(i, {}))
            G[i] = f(par[i]) @ L if i in par else L
        return G[i]

    return f


def rot(M):
    R = M[:3, :3].copy()
    return R / np.linalg.norm(R, axis=0, keepdims=True)


def m2q(R):
    t = np.trace(R)
    if t > 0:
        s = np.sqrt(t + 1) * 2
        q = [(R[2, 1] - R[1, 2]) / s, (R[0, 2] - R[2, 0]) / s, (R[1, 0] - R[0, 1]) / s, s / 4]
    else:
        i = int(np.argmax(np.diag(R)))
        if i == 0:
            s = np.sqrt(1 + R[0, 0] - R[1, 1] - R[2, 2]) * 2
            q = [s / 4, (R[0, 1] + R[1, 0]) / s, (R[0, 2] + R[2, 0]) / s, (R[2, 1] - R[1, 2]) / s]
        elif i == 1:
            s = np.sqrt(1 + R[1, 1] - R[0, 0] - R[2, 2]) * 2
            q = [(R[0, 1] + R[1, 0]) / s, s / 4, (R[1, 2] + R[2, 1]) / s, (R[0, 2] - R[2, 0]) / s]
        else:
            s = np.sqrt(1 + R[2, 2] - R[0, 0] - R[1, 1]) * 2
            q = [(R[0, 2] + R[2, 0]) / s, (R[1, 2] + R[2, 1]) / s, s / 4, (R[1, 0] - R[0, 1]) / s]
    q = np.array(q)
    return q / np.linalg.norm(q)


def swing(a, b):
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    v = np.cross(a, b)
    c = float(a @ b)
    if c < -0.999:
        return -np.eye(3)
    V = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + V + V @ V / (1 + c)


def tipnode(r):
    k = nid[r]
    while N[k].get("children"):
        k = [c for c in N[k]["children"] if N[c]["name"].startswith("Bone_")][0]
    return k


def yaw(R):  # heading of the hips' forward (+Z local) in world XZ
    f = R @ np.array([0, 0, 1.0])
    return np.arctan2(f[0], f[2])


def segpt(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / (ab @ ab), 0, 1)
    return a + t * ab


# ---- r2: whole-chain hang. Each coat chain root -> mid -> stub -> leaf (e.g. Bone_008/007/006/005): root, mid and leaf
# are solved one after another: gravity hang (rest dir turned by the hips' yaw), pushed out of the thigh/shin capsules,
# folded onto the floor (trailing behind the hips) instead of the whole straight chain swinging. The 4 cm stub keeps
# Meshy's key. The leaf's end is a virtual point at the coat hem (lowest cloth weighted to the leaf).
CH = {}
for r in ROOTS:
    k = nid[r]
    c = [k]
    while N[k].get("children"):
        k = [x for x in N[k]["children"] if N[x]["name"].startswith("Bone_")][0]
        c.append(k)
    CH[r] = c
H = nid["Hips"]
LEGS = [(s + "UpLeg", s + "Leg", s + "Foot") for s in ("Left", "Right")]
F0 = glob({})
P0 = lambda F, i: F(i)[:3, 3]
jix = {n: i for i, n in enumerate(m.names)}


def hem(leaf):
    w = (m.W * (m.J == jix[N[leaf]["name"]])).sum(1)
    s_ = w > 0.3
    if s_.sum() < 20:
        return None
    Y = m.bind[s_]
    lo = Y[Y[:, 1] <= np.quantile(Y[:, 1], 0.1)]
    return lo.mean(0)


VL = {}
for r in ROOTS:
    v = hem(CH[r][3])
    if v is None:  # leaf without cloth (side chains): use the mid-bone's cloth hem below the stub
        v = P0(F0, CH[r][3]) + np.array([0, -0.12, 0])
    VL[r] = np.linalg.inv(F0(CH[r][3])) @ np.append(v, 1.0)
SEG = (0, 1, 3)  # solved chain indices
LEGFIX = True


def segd(P, A, B):
    ab = B - A
    t = np.clip(((P - A) @ ab) / (ab @ ab), 0, 1)
    return np.linalg.norm(P - (A + t[:, None] * ab), axis=1)


LEGR = []
for s_ in ("Left", "Right"):
    for a_, b2 in ((s_ + "UpLeg", s_ + "Leg"), (s_ + "Leg", s_ + "Foot")):
        w_ = (m.W * (m.J == jix[a_])).sum(1) > 0.8
        LEGR.append((a_, b2, float(np.median(segd(m.bind[w_], P0(F0, nid[a_]), P0(F0, nid[b2])))) * 0.85))
CM = {r: sum((m.W * (m.J == jix[N[c]["name"]])).sum(1) for c in CH[r]) >= 0.5 for r in ROOTS}
CMlo = {r: sum((m.W * (m.J == jix[N[c]["name"]])).sum(1) for c in CH[r][1:]) >= 0.5 for r in ROOTS}


def endp(F, r, k):
    return (F(CH[r][3]) @ VL[r])[:3] if k == 3 else P0(F, CH[r][k + 1])


REST = {r: {k: endp(F0, r, k) - P0(F0, CH[r][k]) for k in SEG} for r in ROOTS}
LEN = {r: {k: np.linalg.norm(v) for k, v in REST[r].items()} for r in ROOTS}
STUB = {r: P0(F0, CH[r][3]) - P0(F0, CH[r][2]) for r in ROOTS}
R0 = rot(F0(H))
y0 = yaw(R0)
FR = [0.5, 1.0]


def clear_rest(r, k):
    a0 = P0(F0, CH[r][k])
    d = REST[r][k]
    out = []
    for a, b_, c in LEGS:
        for s0, s1, cap in ((a, b_, 0.11), (b_, c, 0.08)):
            A, B = P0(F0, nid[s0]), P0(F0, nid[s1])
            out.append((s0, s1, min(cap, 0.9 * min(np.linalg.norm(a0 + d * f - segpt(a0 + d * f, A, B)) for f in FR))))
    return out


CLR = {r: {k: clear_rest(r, k) for k in SEG} for r in ROOTS}
foot_bind = min(F0(nid[s + "Foot"])[1, 3] for s in ("Left", "Right"))
floor_off = foot_bind - m.y0
print("hem y", {r: round(float(endp(F0, r, 3)[1]), 3) for r in ROOTS})


def solve_chain(F, r, lift=0.0, grow=0.0):
    Rh = rot(F(H))
    a = yaw(Rh) - y0
    c, s = np.cos(a), np.sin(a)
    Ry = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
    floor = min(F(nid[s_ + "Foot"])[1, 3] for s_ in ("Left", "Right")) - floor_off + 0.03 + lift
    bk = -(Rh @ np.array([0, 0, 1.0]))
    bk[1] = 0
    bk = bk / max(np.linalg.norm(bk), 1e-6)
    p = P0(F, CH[r][0])
    dirs = {}
    prev = None
    for k in SEG:
        Ln = LEN[r][k]
        d = Ry @ REST[r][k]
        d = d / np.linalg.norm(d)
        for _ in range(6):
            moved = False
            for s0, s1, thr in CLR[r][k]:
                thr = thr + grow
                A, B = P0(F, nid[s0]), P0(F, nid[s1])
                for f in FR:
                    q_ = p + d * Ln * f
                    qq = segpt(q_, A, B)
                    e = q_ - qq
                    L = np.linalg.norm(e)
                    if L < thr - 1e-4:
                        e = e / L if L > 1e-6 else np.array([0, 0, -1.0])
                        p2 = qq + e * thr
                        d = (p2 - p) / np.linalg.norm(p2 - p)
                        moved = True
            if (p + d * Ln)[1] < floor - 1e-4:
                dy = min(floor - p[1], 0.0)
                hz = np.array([d[0], 0, d[2]])
                hz = hz / np.linalg.norm(hz) if np.linalg.norm(hz) > 1e-3 else bk
                hz = 0.4 * hz + 0.6 * bk
                hz = hz / max(np.linalg.norm(hz), 1e-6)
                d = hz * np.sqrt(max(Ln * Ln - dy * dy, 0.0)) / Ln + np.array([0, dy / Ln, 0])
                d = d / np.linalg.norm(d)
                moved = True
            if not moved:
                break
        if prev is not None and float(d @ prev) < 0.17:  # cloth folds at most ~80 deg per joint
            d = g.slerp(prev, d, 0.75)
        dirs[k] = d
        prev = d
        p = p + d * Ln
        if k == 1:
            p = p + d * np.linalg.norm(STUB[r])
    return [dirs[k] for k in SEG]


def chain_keys(an, T, loop, LIFT, GROW):
    D = {r: [] for r in ROOTS}
    base = [m.sample(an, float(t)) for t in T]
    for i, o in enumerate(base):
        F = glob(o)
        for r in ROOTS:
            D[r].append(solve_chain(F, r, LIFT[r][i], GROW[r][i]))
    for r in ROOTS:
        dd = np.array(D[r])
        n = len(dd)
        if n > 3:
            for _ in range(2):
                sm = dd.copy()
                for i in range(n):
                    a, b_ = ((i - 1) % n, (i + 1) % n) if loop else (max(i - 1, 0), min(i + 1, n - 1))
                    sm[i] = 0.25 * dd[a] + 0.5 * dd[i] + 0.25 * dd[b_]
                dd = sm / np.linalg.norm(sm, axis=2, keepdims=True)
        D[r] = dd
    OV = []
    Q = {(r, k): [] for r in ROOTS for k in SEG}
    ANG = {(r, k): [] for r in ROOTS for k in SEG}
    for i, o in enumerate(base):
        over = {kk: dict(v) for kk, v in o.items()}
        for r in ROOTS:
            for si, k in enumerate(SEG):
                F = glob(over)
                b = CH[r][k]
                Rp = rot(F(par[b]))
                dp = endp(F, r, k) - P0(F, b)
                S = swing(dp, D[r][i][si])
                Lr = g.q2m(over.get(b, {}).get("rotation", N[b].get("rotation", [0, 0, 0, 1])))
                q = m2q(Rp.T @ S @ Rp @ Lr)
                if Q[(r, k)] and q @ Q[(r, k)][-1] < 0:
                    q = -q
                Q[(r, k)].append(q)
                over.setdefault(b, {})["rotation"] = q
                ANG[(r, k)].append(np.degrees(np.arccos(np.clip((dp / np.linalg.norm(dp)) @ D[r][i][si], -1, 1))))
        OV.append(over)
    return Q, ANG, OV


out_acc = []
for an in j["animations"]:
    ch = {(N[c["target"]["node"]]["name"], c["target"]["path"]): c for c in an["channels"]}
    hs = an["samplers"][ch[("Hips", "rotation")]["sampler"]]
    T = g.acc(j, m.b, hs["input"]).ravel()
    loop = an["name"] in ("Idle",) or "walking" in an["name"] or "running" in an["name"]
    LIFT = {r: np.zeros(len(T)) for r in ROOTS}
    GROW = {r: np.zeros(len(T)) for r in ROOTS}
    for it in range(8):
        Q, ANG, OV = chain_keys(an, T, loop, LIFT, GROW)
        worst = 0.0
        legn = 0
        for i, o in enumerate(OV):
            X = m.skin(o)
            for r in ROOTS:
                dep = max(0.0, m.y0 - 0.005 - float(X[CM[r], 1].min()))
                if dep > 0:
                    LIFT[r][i] += 1.5 * dep + 0.01
                    worst = max(worst, dep)
                if LEGFIX:
                    Fo = glob(o)
                    Xc = X[CMlo[r]]
                    ins = np.zeros(len(Xc), bool)
                    for a_, b2, rr in LEGR:
                        ins |= segd(Xc, Fo(nid[a_])[:3, 3], Fo(nid[b2])[:3, 3]) < rr
                    n_ = int(ins.sum())
                    legn += n_
                    if n_ > 20 and GROW[r][i] < 0.12:
                        GROW[r][i] += 0.03
        print(
            f"  {an['name'][:24]} pass {it} worst coat depth under floor {worst * 100:.1f} cm, lower-coat verts in legs {legn}"
        )
        if (worst < 0.005 and not LEGFIX) or it == 7:
            break
        for r in ROOTS:  # widen each lift to the neighbour frames so smoothing cannot pull the hem back under
            L = LIFT[r]
            LIFT[r] = np.maximum(L, np.maximum(np.roll(L, 1), np.roll(L, -1)) * 0.8)
    for r in ROOTS:
        for k in SEG:
            b = N[CH[r][k]]["name"]
            c = ch[(b, "rotation")]
            smp = an["samplers"][c["sampler"]]
            smp["input"] = hs["input"]
            smp["interpolation"] = "LINEAR"
            out_acc.append((smp, np.array(Q[(r, k)], np.float32)))
        print(
            f"{an['name'][:24]:24s} {r} turn deg max/mean "
            + " ".join(f"{max(ANG[(r, k)]):5.1f}/{np.mean(ANG[(r, k)]):4.1f}" for k in SEG)
        )

bin_ = bytearray(m.b)
for smp, arr in out_acc:
    while len(bin_) % 4:
        bin_ += b"\0"
    j["bufferViews"].append({"buffer": 0, "byteOffset": len(bin_), "byteLength": arr.nbytes})
    bin_ += arr.tobytes()
    j["accessors"].append(
        {"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126, "count": len(arr), "type": "VEC4"}
    )
    smp["output"] = len(j["accessors"]) - 1
while len(bin_) % 4:
    bin_ += b"\0"
j["buffers"][0]["byteLength"] = len(bin_)
js = json.dumps(j, separators=(",", ":")).encode()
js += b" " * ((4 - len(js) % 4) % 4)
with open(OUT, "wb") as f:
    f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bin_)))
    f.write(struct.pack("<II", len(js), 0x4E4F534A))
    f.write(js)
    f.write(struct.pack("<II", len(bin_), 0x004E4942))
    f.write(bin_)
print("wrote", OUT)
