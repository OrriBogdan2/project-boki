"""handparts.py GLB: which primitives/materials feed geo_check's hand_L/hand_R and their shapes."""
import sys, numpy as np
sys.path.insert(0, __file__.rsplit('/', 3)[0] + '/anim')
import geo_check as g
c = g.Check(sys.argv[1], 'hem')
print([k for k in c.parts if 'hand' in k])
print('mesh keys', list(c.mesh.keys()))
for k, (ids, th) in c.hand_ids().items():
    print(k, len(ids), 'shape', [round(x, 2) if x is not None else None for x in g.hand_shape(c.mesh['pos'][ids], th)])
    if 'prim' in c.mesh: print('  prims', np.unique(c.mesh['prim'][ids], return_counts=True))
np.save('/tmp/handids.npy', np.concatenate([v[0] for v in c.hand_ids().values()]))
for k, (ids, th) in c.hand_ids().items():
    m = c.mesh['mat'] if len(c.mesh['mat']) == len(c.mesh['pos']) else None
    print(k, 'mat len', len(c.mesh['mat']), 'pos', len(c.mesh['pos']))
    if m is not None: print('  mats', np.unique(m[ids], return_counts=True))
    p = c.mesh['pos'][ids]; print('  bbox', p.min(0).round(3), p.max(0).round(3))
ids, th = c.hand_ids()['hand_L']
for mname in ['head_graft|body-hand17', 'head_graft|body-retex']:
    s = ids[c.mesh['mat'][ids] == mname]; p = c.mesh['pos'][s]
    print(mname, len(s), 'shape', [round(x, 2) if x is not None else None for x in g.hand_shape(p, th[c.mesh['mat'][ids] == mname])], 'bbox', p.min(0).round(3), p.max(0).round(3))
    print('  dom bones', np.unique([c.rig.names[d] for d in c.dom[s]], return_counts=True))
