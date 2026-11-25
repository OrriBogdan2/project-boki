"""leftover.py GLB: old body-retex verts in geo's hand_L: per dominant bone, how many sit inside the r17 fist's hull."""
import sys, numpy as np
from scipy.spatial import Delaunay
sys.path.insert(0, __file__.rsplit('/', 3)[0] + '/anim')
import geo_check as g
c = g.Check(sys.argv[1], 'hem'); ids, th = c.hand_ids()['hand_L']
mat = c.mesh['mat'][ids]; P = c.mesh['pos']
fist = P[ids[mat == 'head_graft|body-hand17']]; old = ids[mat == 'head_graft|body-retex']
inside = Delaunay(fist).find_simplex(P[old]) >= 0
names = np.array([c.rig.names[d] for d in c.dom[old]])
for n in np.unique(names):
    s = names == n; print(n, s.sum(), 'inside fist', inside[s].sum(), 'y', P[old[s]][:, 1].min().round(3), P[old[s]][:, 1].max().round(3))
np.save(sys.argv[2], old)
np.save(sys.argv[2].replace('.npy', '_pos.npy'), P[old])
print('dom raw joints', np.unique(c.dom[old], return_counts=True))
