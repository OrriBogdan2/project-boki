"""glb_leg_narrow.py IN.glb OUT.glb CLIP ALPHA T0 PEAK T1 [MAXDEG]: in [T0,T1] (smoothstep to PEAK) each thigh (UpLeg->Leg) is turned a fraction
Made 11-26 for Meeko r15: her Attack holds the thighs ~100-110 deg apart (Idle 25) and the crotch skin stretched (mesh_check 462
tris); weights/relax made it worse (r14), so the pose itself is eased. Run: python3 tools/art1/glb_leg_narrow.py IN OUT Attack 0.35 0.7 1.6 2.5 40
ALPHA of the way back toward its Idle-f0 direction (relative to Hips), capped at MAXDEG; then Hips is moved in y so the lowest
foot joint (Foot/ToeBase) keeps its original height per key (feet stay on the ground). Keys only."""

import sys, numpy as np

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from glb_add_clips import read, write
from glb_key_pose import Clip, qmul, qinv, qrot, ease

src, out, clip = sys.argv[1:4]
alpha, t0, pk, t1 = map(float, sys.argv[4:8])
maxdeg = float(sys.argv[8]) if len(sys.argv) > 8 else 40
j, b = read(src)
idle = Clip(j, b, "Idle")
c = Clip(j, b, clip)
H = c.names["Hips"]


def local_dir(cl, side, k):  # thigh dir in Hips space
    u = cl.world(cl.names[side + "UpLeg"], k)[1]
    kn = cl.world(cl.names[side + "Leg"], k)[1]
    hq = cl.world(H, k)[0]
    v = qrot(qinv(hq), kn - u)
    return v / np.linalg.norm(v)


ref = {s: local_dir(idle, s, 0) for s in ("Left", "Right")}


def feet_min(k):
    return min(c.world(c.names[s + p], k)[1][1] for s in ("Left", "Right") for p in ("Foot", "ToeBase"))


node = c.names["LeftUpLeg"]
toff, voff, count = c.rot[node]
times = np.frombuffer(bytes(b[toff : toff + 4 * count]), "<f4")
log = []
for k in range(count):
    w = ease(float(times[k]), t0, pk, t1)
    if w == 0:
        continue
    y0 = feet_min(k)
    angs = []
    for s in ("Left", "Right"):
        n = c.names[s + "UpLeg"]
        v = local_dir(c, s, k)
        d = ref[s]
        ax = np.cross(v, d)
        sn = np.linalg.norm(ax)
        if sn < 1e-6:
            continue
        full = np.arctan2(sn, v @ d)
        a = min(full * alpha * w, np.radians(maxdeg) * w)
        angs.append(np.degrees(a))
        # rotation in Hips space -> to the UpLeg's parent space
        hq = c.world(H, k)[0]
        pq = c.world(c.parent[n], k)[0]
        dq_h = np.append(ax / sn * np.sin(a / 2), np.cos(a / 2))
        dq_w = qmul(qmul(hq, dq_h), qinv(hq))
        q = qmul(qmul(qmul(qinv(pq), dq_w), pq), c.get(c.rot, n, k, 4, "rotation"))
        tv, vv, cn = c.rot[n]
        b[vv + 16 * k : vv + 16 * k + 16] = (q / np.linalg.norm(q)).astype("<f4").tobytes()
    dy = y0 - feet_min(k)
    if H in c.pos:
        tp, vp, cp = c.pos[H]
        p = c.get(c.pos, H, k, 3, "translation")
        pq = c.world(c.parent[H], k)[0] if H in c.parent else np.array([0, 0, 0, 1.0])
        p = p + qrot(qinv(pq), np.array([0, dy, 0]))
        b[vp + 12 * k : vp + 12 * k + 12] = p.astype("<f4").tobytes()
    log.append((round(float(times[k]), 2), [round(x, 1) for x in angs], round(dy, 3)))
write(out, j, b)
print("keys", len(log), "max turn", max(max(a) for _, a, _ in log if a), "max hips dy", max(abs(d) for *_, d in log))
