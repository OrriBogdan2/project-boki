"""drop_prim37.py IN.glb OUT.glb MATNAME: remove every primitive whose material is MATNAME (raw glb edit; buffers untouched,
the orphaned accessors stay). r37: drop the r36 hair35 blob before adding the locks37 hair."""
import sys
sys.path.insert(0, __file__.rsplit('/', 2)[0] + '/hem_r17')
from glbio import load, save
j, b = load(sys.argv[1]); n = 0
for m in j['meshes']:
    keep = [p for p in m['primitives'] if j['materials'][p['material']]['name'] != sys.argv[3]]; n += len(m['primitives']) - len(keep); m['primitives'] = keep
save(sys.argv[2], j, b); print('dropped %d prims with material %s' % (n, sys.argv[3]))
