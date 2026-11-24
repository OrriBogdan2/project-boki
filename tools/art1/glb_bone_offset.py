"""Keys only: constant model-space rotation offset on one bone, every key of the given clips (keys only).
Run: tools/art1/glb_bone_offset.py IN OUT CLIPS(comma) BONE AXIS(x,y,z) DEG [BONE AXIS DEG ...]"""
import sys, numpy as np
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from glb_add_clips import read, write
from glb_key_pose import Clip, qmul, qinv
src, dst, clips = sys.argv[1:4]; rest = sys.argv[4:]
j, b = read(src)
for clip in clips.split(','):
    for i in range(0, len(rest), 3):
        c = Clip(j, b, clip)
        node = c.names[rest[i]]; ax = np.array([float(x) for x in rest[i+1].split(',')]); ax /= np.linalg.norm(ax)
        h = np.radians(float(rest[i+2])) / 2; delta = np.append(ax*np.sin(h), np.cos(h))
        toff, voff, count = c.rot[node]
        for k in range(count):
            pq, _ = c.world(c.parent[node], k)
            q = qmul(qmul(qmul(qinv(pq), delta), pq), c.get(c.rot, node, k, 4, 'rotation'))
            b[voff+16*k:voff+16*k+16] = (q/np.linalg.norm(q)).astype('<f4').tobytes()
write(dst, j, b)
