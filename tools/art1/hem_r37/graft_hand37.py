"""graft_hand37.py BASE.glb LIVE.glb OUT.glb: Lace r37 right-hand graft.
Why: r34/r35 replaced Lace's right hand with prim 'body-hand33' (Meshy hand); geo_check finds it flatter than live
(ratio 0.41 vs 0.63, finger separation 0.21 vs 0.32) and attack shows a dark hole at the wrist seam.
How: live's body-retex faces that touch a vertex missing from BASE's body-retex inside the right-hand box
(x < -0.30, y > 0.85 m, glTF rest pose) are copied with all their attributes into the body-hand33 primitive slot
(new accessors appended; material = BASE's body-retex, same texD2 texels: mean diff 1.2/255 at those UVs).
The seam ring is live's own wrist vertices, which BASE still has, so no gap. Every other primitive is unchanged."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'hem_r17'))
import numpy as np
from scipy.spatial import cKDTree
from glbio import load, acc, save

base, live, out = sys.argv[1:4]
jb, bb = load(base); jl, bl = load(live)
nb = [jb['nodes'][n]['name'] for n in jb['skins'][0]['joints']]
nl = [jl['nodes'][n]['name'] for n in jl['skins'][0]['joints']]
assert nb[:len(nl)] == nl, 'live joints must be a prefix of base joints'
mat = {m['name']: i for i, m in enumerate(jb['materials'])}


def find(j, name):
    for mi, m in enumerate(j['meshes']):
        for pi, p in enumerate(m['primitives']):
            if j['materials'][p['material']]['name'] == name: return mi, pi
    raise SystemExit('no prim ' + name)


lm, lp = find(jl, 'body-retex'); bm, bp = find(jb, 'body-retex'); hm, hp = find(jb, 'body-hand33')
LP = jl['meshes'][lm]['primitives'][lp]; A = {k: acc(jl, bl, v) for k, v in LP['attributes'].items()}
F = acc(jl, bl, LP['indices']).reshape(-1, 3)
BP = acc(jb, bb, jb['meshes'][bm]['primitives'][bp]['attributes']['POSITION'])
d, _ = cKDTree(BP).query(A['POSITION']); miss = d > 1e-5
P = A['POSITION']; g = miss & (P[:, 0] < -0.30) & (P[:, 1] > 0.85)
fk = g[F].any(1); Fg = F[fk]; used = np.unique(Fg); remap = -np.ones(len(P), int); remap[used] = np.arange(len(used))
print('graft verts', len(used), 'faces', len(Fg), 'missing-in-box', int(g.sum()))
bb = bytearray(bb)


def addacc(arr, src_acc):
    global bb
    sa = jl['accessors'][src_acc]
    from glbio import CT
    raw = np.ascontiguousarray(arr.astype(np.dtype(CT[sa['componentType']]))).tobytes()
    bb += b'\0' * ((-len(bb)) % 4); off = len(bb); bb += raw
    jb['bufferViews'].append({'buffer': 0, 'byteOffset': off, 'byteLength': len(raw)})
    a = {k: v for k, v in sa.items() if k not in ('bufferView', 'byteOffset', 'min', 'max', 'sparse')}
    a['bufferView'] = len(jb['bufferViews']) - 1; a['count'] = len(arr)
    if sa['type'] == 'VEC3' and k_is_pos[0]:
        a['min'] = [float(x) for x in arr.min(0)]; a['max'] = [float(x) for x in arr.max(0)]
    jb['accessors'].append(a); return len(jb['accessors']) - 1


attrs = {}
for k, v in LP['attributes'].items():
    k_is_pos = [k == 'POSITION']
    attrs[k] = addacc(A[k][used], v)
k_is_pos = [False]
ind = addacc(remap[Fg].reshape(-1).astype(np.uint32), LP['indices'])
jb['accessors'][ind]['componentType'] = 5125
jb['bufferViews'][jb['accessors'][ind]['bufferView']]['byteLength'] = len(Fg) * 3 * 4
# rewrite index bytes as uint32 in case the source was uint16
o = jb['bufferViews'][jb['accessors'][ind]['bufferView']]['byteOffset']
bb[o:o + len(Fg) * 12] = np.ascontiguousarray(remap[Fg].reshape(-1).astype(np.uint32)).tobytes()
pr = jb['meshes'][hm]['primitives'][hp]
pr['attributes'] = attrs; pr['indices'] = ind; pr['material'] = mat['body-retex']; pr.pop('targets', None)
jb['buffers'][0]['byteLength'] = len(bb)
save(out, jb, bb); print('wrote', out)
