"""Keys only: constant model-space rotation offset on one bone, every key of the given clips (keys only).
Run: tools/art1/glb_bone_offset.py IN OUT CLIPS(comma) BONE AXIS(x,y,z) DEG [BONE AXIS DEG ...] [--window=T0,T1,RAMP]
--window (11-26, Meeko r15): the offset is full between T0+RAMP and T1-RAMP s, eased in/out over RAMP, 0 outside, so a
pose fix can skip the frames where it would hurt (Jump_Run takeoff, where the R paw crosses the chest)."""
import sys, numpy as np
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from glb_add_clips import read, write
from glb_key_pose import Clip, qmul, qinv
win = [a for a in sys.argv if a.startswith('--window=')]
args = [a for a in sys.argv if not a.startswith('--window=')]
src, dst, clips = args[1:4]; rest = args[4:]
t0, t1, ramp = (float(x) for x in win[0][9:].split(',')) if win else (-1e9, 1e9, 1e-9)
sm = lambda x: np.clip(x, 0, 1) ** 2 * (3 - 2 * np.clip(x, 0, 1))
j, b = read(src)
for clip in clips.split(','):
    for i in range(0, len(rest), 3):
        c = Clip(j, b, clip)
        node = c.names[rest[i]]; ax = np.array([float(x) for x in rest[i+1].split(',')]); ax /= np.linalg.norm(ax)
        toff, voff, count = c.rot[node]
        times = np.frombuffer(bytes(b[toff:toff + 4 * count]), '<f4')
        for k in range(count):
            w = min(sm((times[k] - t0) / ramp), sm((t1 - times[k]) / ramp))
            if w <= 0:
                continue
            h = np.radians(float(rest[i+2]) * w) / 2; delta = np.append(ax*np.sin(h), np.cos(h))
            pq, _ = c.world(c.parent[node], k)
            q = qmul(qmul(qmul(qinv(pq), delta), pq), c.get(c.rot, node, k, 4, 'rotation'))
            b[voff+16*k:voff+16*k+16] = (q/np.linalg.norm(q)).astype('<f4').tobytes()
write(dst, j, b)
