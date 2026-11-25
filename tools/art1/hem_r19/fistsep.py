"""fistsep.py GLB...: geo_check hand_shape (thickness ratio, finger sep) on all mesh POSITION verts of each glb (fist candidates)."""
import sys, numpy as np
sys.path.insert(0, __file__.rsplit('/', 3)[0] + '/anim'); sys.path.insert(0, __file__.rsplit('/', 2)[0] + '/hem_r17')
from geo_check import hand_shape
import glbio
for p in sys.argv[1:]:
    j, b = glbio.load(p)
    v = np.concatenate([glbio.acc(j, b, pr['attributes']['POSITION']) for m in j['meshes'] for pr in m['primitives']])
    r, lobe, sep = hand_shape(v.astype(float), np.zeros(len(v), bool))
    print(p.split('/')[-1], len(v), 'ratio %.2f sep %.2f' % (r, sep))
