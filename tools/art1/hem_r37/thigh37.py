"""thigh37.py BASE.glb LIVE.glb OUT.glb [--box x0,x1,y0,y1,zmin]: Lace r37 upper right thigh under the front slit.
Why: the r37 slit (slit37.py) runs up to the hip so the porcelain leg reads from the high game camera, but BASE's body-retex
was trimmed under the Meshy skirt and leg-meshy stops at y 0.90 except for its outer edge (x < -0.14): in Godot the game
camera looked through the top of the slit straight down to the ground (green hole, r37 NEW idle_1).
How: live's body-retex faces inside the box (glTF rest pose; default her right hip, front half) that touch a vertex missing
from BASE's body-retex are appended as a new body-retex primitive in the same mesh (same skin, same texture; live joints are a
prefix of BASE's, as in graft_hand37.py). Every other primitive is unchanged."""
import sys, os, argparse
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'hem_r17'))
import numpy as np
from scipy.spatial import cKDTree
from glbio import load, acc, save, CT

ap = argparse.ArgumentParser(); ap.add_argument('base'); ap.add_argument('live'); ap.add_argument('out')
ap.add_argument('--box', default='-0.145,-0.02,0.84,1.00,-0.06')
a = ap.parse_args(); x0, x1, y0, y1, zmin = map(float, a.box.split(','))
jb, bb = load(a.base); jl, bl = load(a.live); bb = bytearray(bb)
nb = [jb['nodes'][n]['name'] for n in jb['skins'][0]['joints']]; nl = [jl['nodes'][n]['name'] for n in jl['skins'][0]['joints']]
assert nb[:len(nl)] == nl, 'live joints must be a prefix of base joints'


def find(j, name):
    for mi, m in enumerate(j['meshes']):
        for pi, p in enumerate(m['primitives']):
            if j['materials'][p['material']]['name'] == name: return mi, pi
    raise SystemExit('no prim ' + name)


lm, lp = find(jl, 'body-retex'); bm, bp = find(jb, 'body-retex')
LP = jl['meshes'][lm]['primitives'][lp]; A = {k: acc(jl, bl, v) for k, v in LP['attributes'].items()}
F = acc(jl, bl, LP['indices']).astype(np.int64).reshape(-1, 3); P = A['POSITION'].astype(float)
BP = np.vstack([acc(jb, bb, p['attributes']['POSITION']) for p in jb['meshes'][bm]['primitives']
                if jb['materials'][p['material']]['name'] == 'body-retex']).astype(float)
miss = cKDTree(BP).query(P)[0] > 1e-5
C = P[F].mean(1)
fk = miss[F].any(1) & (C[:, 0] > x0) & (C[:, 0] < x1) & (C[:, 1] > y0) & (C[:, 1] < y1) & (C[:, 2] > zmin)
Fg = F[fk]; used = np.unique(Fg); remap = -np.ones(len(P), np.int64); remap[used] = np.arange(len(used))
print('thigh graft: %d faces, %d verts, y %.3f..%.3f' % (len(Fg), len(used), P[used, 1].min(), P[used, 1].max()))


def addacc(arr, src):
    global bb
    sa = jl['accessors'][src] if src is not None else {'componentType': 5125, 'type': 'SCALAR'}
    raw = np.ascontiguousarray(arr.astype(CT[sa['componentType']])).tobytes()
    bb += b'\0' * ((-len(bb)) % 4); off = len(bb); bb += raw
    jb['bufferViews'].append({'buffer': 0, 'byteOffset': off, 'byteLength': len(raw)})
    acc_ = {k: v for k, v in sa.items() if k not in ('bufferView', 'byteOffset', 'min', 'max', 'sparse')}
    acc_['bufferView'] = len(jb['bufferViews']) - 1; acc_['count'] = len(arr)
    if arr.ndim == 2 and arr.shape[1] == 3 and src == LP['attributes']['POSITION']:
        acc_['min'] = [float(v) for v in arr.min(0)]; acc_['max'] = [float(v) for v in arr.max(0)]
    jb['accessors'].append(acc_); return len(jb['accessors']) - 1


attrs = {k: addacc(A[k][used], v) for k, v in LP['attributes'].items()}
ind = addacc(remap[Fg].reshape(-1), None)
src = jb['meshes'][bm]['primitives'][bp]
jb['meshes'][bm]['primitives'].append({'attributes': attrs, 'indices': ind, 'material': src['material'], 'mode': src.get('mode', 4)})
jb['buffers'][0]['byteLength'] = len(bb)
save(a.out, jb, bytes(bb)); print('thigh37 ->', a.out)
